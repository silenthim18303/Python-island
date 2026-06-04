//
//  GitHubService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation
import Combine
import Security
import AppKit

// MARK: - URL Session Delegate (绕过代理 TLS 验证)

/// 代理（Clash 等）会拦截 HTTPS 并注入自签名证书，导致 TLS 握手失败。
/// 此 delegate 仅对 GitHub API 域名跳过证书验证。
private class GitHubSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host
        // 仅对 GitHub 相关域名跳过验证，其他域名走默认流程
        if host.hasSuffix("github.com") || host.hasSuffix("githubusercontent.com") || host.hasSuffix("github.io") {
            completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - GitHub Service

/// GitHub API 服务 — 壁纸上传/下载（Device Flow 授权，无需手动配置 Token）
@MainActor
final class GitHubService: ObservableObject {
    static let shared = GitHubService()

    @Published var isAuthenticated = false
    @Published var isAuthorizing = false
    @Published var deviceCode: String?
    @Published var userCode: String?
    @Published var verificationURI: String?

    private let repoOwner = "MacIsland"
    private let repoName = "wallpaper4MacIsland"
    private let apiBase = "https://api.github.com"
    private let cdnBase = "https://cdn.jsdelivr.net/gh"
    private let mainBranch = "main"
    private let pendingBranch = "pending-uploads"

    // GitHub OAuth App (Device Flow)
    /// 内置 Client ID，用户无需配置
    private let builtinClientID = "Ov23li5Gsly8EYOKJEaJ"
    private var clientID: String {
        let stored = UserDefaults.standard.string(forKey: "githubClientID") ?? ""
        return stored.isEmpty ? builtinClientID : stored
    }

    /// 文件大小上限（GitHub API 限制 100MB）
    static let uploadFilesizeLimit: Int64 = 100 * 1024 * 1024

    /// 专用 URLSession — 绕过代理 TLS 证书验证（Clash 等代理会拦截 HTTPS）
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config, delegate: GitHubSessionDelegate(), delegateQueue: nil)
    }()

    private var token: String? {
        KeychainHelper.load(key: "github_token")
    }

    var authHeaders: [String: String] {
        var headers: [String: String] = [
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "MacIsland/1.0",
        ]
        if let token = token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }

    private init() {
        isAuthenticated = token != nil
    }

    // MARK: - Device Flow Authorization

    /// 启动 Device Flow 授权
    func startDeviceFlow() async {
        isAuthorizing = true

        guard !clientID.isEmpty else {
            print("[GitHub] Client ID 未配置")
            isAuthorizing = false
            return
        }

        guard let url = URL(string: "https://github.com/login/device/code") else {
            isAuthorizing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "client_id": clientID,
            "scope": "repo",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let deviceCode = json["device_code"] as? String,
                  let userCode = json["user_code"] as? String,
                  let verificationURI = json["verification_uri"] as? String else {
                print("[GitHub] Device Flow 响应解析失败")
                isAuthorizing = false
                return
            }

            self.deviceCode = deviceCode
            self.userCode = userCode
            self.verificationURI = verificationURI

            print("[GitHub] Device Code: \(deviceCode)")
            print("[GitHub] User Code: \(userCode)")
            print("[GitHub] 请在浏览器中完成授权: \(verificationURI)")

            // 打开浏览器让用户授权
            if let url = URL(string: verificationURI) {
                NSWorkspace.shared.open(url)
            }

            // 轮询等待授权完成
            let interval = json["interval"] as? Int ?? 5
            await pollForToken(deviceCodeValue: deviceCode, interval: interval)
        } catch {
            print("[GitHub] Device Flow 启动失败: \(error)")
            isAuthorizing = false
        }
    }

    /// 轮询等待用户授权
    @MainActor
    private func pollForToken(deviceCodeValue: String, interval: Int) async {
        var currentInterval = interval
        print("[GitHub] 开始轮询授权状态，间隔 \(currentInterval)s")
        while isAuthorizing {
            try? await Task.sleep(for: .seconds(currentInterval))

            guard let url = URL(string: "https://github.com/login/oauth/access_token") else { break }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let body: [String: Any] = [
                "client_id": clientID,
                "device_code": deviceCodeValue,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await session.data(for: request)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("[GitHub] 轮询响应解析失败")
                    break
                }

                if let accessToken = json["access_token"] as? String {
                    // 授权成功
                    print("[GitHub] 授权成功！")
                    saveToken(accessToken)
                    isAuthorizing = false
                    deviceCode = nil
                    userCode = nil
                    verificationURI = nil
                    return
                }

                if let error = json["error"] as? String {
                    if error == "authorization_pending" {
                        continue // 等待用户授权
                    } else if error == "slow_down" {
                        // GitHub 要求增加轮询间隔
                        currentInterval += 5
                        continue
                    } else {
                        // 其他错误（expired_token 等）
                        isAuthorizing = false
                        return
                    }
                }
            } catch {
                break
            }
        }
    }

    /// 取消授权
    func cancelAuthorization() {
        isAuthorizing = false
        deviceCode = nil
        verificationURI = nil
    }

    // MARK: - Token Management

    func saveToken(_ token: String) {
        KeychainHelper.save(key: "github_token", value: token)
        isAuthenticated = true
    }

    func removeToken() {
        KeychainHelper.delete(key: "github_token")
        isAuthenticated = false
    }

    /// 设置 GitHub OAuth App Client ID（Device Flow 必需）
    func setClientID(_ id: String) {
        UserDefaults.standard.set(id, forKey: "githubClientID")
    }

    // MARK: - Upload with Review

    /// 上传壁纸并创建 PR 等待审核
    func uploadWallpaper(
        username: String,
        wallpaperName: String,
        data: Data,
        isVideo: Bool
    ) async throws -> String {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        guard data.count <= Self.uploadFilesizeLimit else {
            throw GitHubError.uploadFailed("文件大小超过 100MB 限制")
        }

        // 检查仓库是否存在
        let repoURL = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)")!
        var repoRequest = URLRequest(url: repoURL)
        for (key, value) in authHeaders { repoRequest.setValue(value, forHTTPHeaderField: key) }
        repoRequest.timeoutInterval = 8
        do {
            let (repoData, repoResponse) = try await session.data(for: repoRequest)
            if let http = repoResponse as? HTTPURLResponse {
                print("[GitHub] 仓库检查: HTTP \(http.statusCode)")
                if http.statusCode == 404 {
                    throw GitHubError.uploadFailed("社区仓库暂未开放，上传功能即将上线")
                }
                if http.statusCode == 403 {
                    let body = String(data: repoData, encoding: .utf8) ?? ""
                    throw GitHubError.uploadFailed("权限不足（HTTP 403），请确认 Token 有 repo 权限")
                }
                if !(200...299).contains(http.statusCode) {
                    throw GitHubError.uploadFailed("服务器返回 HTTP \(http.statusCode)")
                }
            }
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.uploadFailed("网络错误: \(error.localizedDescription)")
        }

        let ext = isVideo ? "mp4" : "jpg"
        let path = "\(username)/\(wallpaperName)/wallpaper.\(ext)"

        // 1. 确保 pending 分支存在
        try await ensureBranchExists(branch: pendingBranch, from: mainBranch)

        // 2. 在 pending 分支上创建文件
        try await createFileOnBranch(
            branch: pendingBranch,
            path: path,
            data: data,
            message: "Upload wallpaper: \(wallpaperName) by \(username)"
        )

        // 3. 创建 PR
        let prURL = try await createPullRequest(
            from: pendingBranch,
            to: mainBranch,
            title: "Upload: \(wallpaperName)",
            body: "用户 **\(username)** 上传了壁纸 **\(wallpaperName)**\n\n类型: \(isVideo ? "视频" : "图片")"
        )

        return prURL
    }

    // MARK: - Delete Wallpaper

    /// 删除社区壁纸并创建 PR
    func deleteWallpaper(username: String, wallpaperName: String, fileExtension: String) async throws -> String {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let path = "\(username)/\(wallpaperName)/wallpaper.\(fileExtension)"

        // 确保 pending 分支存在
        try await ensureBranchExists(branch: pendingBranch, from: mainBranch)

        // 在 pending 分支上删除文件
        try await deleteFile(
            path: path,
            message: "Delete wallpaper: \(wallpaperName) by \(username)",
            branch: pendingBranch
        )

        // 创建 PR
        let prURL = try await createPullRequest(
            from: pendingBranch,
            to: mainBranch,
            title: "Delete: \(wallpaperName)",
            body: "用户 **\(username)** 删除了壁纸 **\(wallpaperName)**"
        )

        return prURL
    }

    // MARK: - Branch Management

    private func ensureBranchExists(branch: String, from baseBranch: String) async throws {
        let url = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/branches/\(branch)")!
        var request = URLRequest(url: url)
        for (key, value) in authHeaders { request.setValue(value, forHTTPHeaderField: key) }

        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print("[GitHub] 分支 \(branch) 检查: HTTP \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 { return }
        }

        print("[GitHub] 分支 \(branch) 不存在，从 \(baseBranch) 创建")
        let baseSHA = try await getBranchSHA(branch: baseBranch)

        let createURL = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/git/refs")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        for (key, value) in authHeaders { createRequest.setValue(value, forHTTPHeaderField: key) }
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["ref": "refs/heads/\(branch)", "sha": baseSHA]
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, createResponse) = try await session.data(for: createRequest)
        guard let httpResponse = createResponse as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.uploadFailed("创建分支失败")
        }
    }

    private func getBranchSHA(branch: String) async throws -> String {
        let url = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/branches/\(branch)")!
        var request = URLRequest(url: url)
        for (key, value) in authHeaders { request.setValue(value, forHTTPHeaderField: key) }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("[GitHub] 获取 \(branch) SHA: HTTP \(http.statusCode)")
            if http.statusCode == 404 {
                throw GitHubError.uploadFailed("分支 \(branch) 不存在，请先在仓库中创建至少一个提交")
            }
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["commit"] as? [String: Any],
              let sha = commit["sha"] as? String else {
            print("[GitHub] SHA 解析失败: \(String(data: data, encoding: .utf8) ?? "")")
            throw GitHubError.uploadFailed("无法读取分支信息")
        }
        print("[GitHub] \(branch) SHA: \(sha)")
        return sha
    }

    // MARK: - File Operations

    private func createFileOnBranch(branch: String, path: String, data: Data, message: String) async throws {
        let url = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        for (key, value) in authHeaders { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": message,
            "content": data.base64EncodedString(),
            "branch": branch,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GitHubError.uploadFailed("文件创建失败")
        }
    }

    // MARK: - Delete File

    /// 删除仓库中的文件（通过 Contents API）
    func deleteFile(path: String, message: String, branch: String) async throws {
        // 1. 获取文件 SHA
        let getUrl = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/contents/\(path)")!
        var getRequest = URLRequest(url: getUrl)
        for (key, value) in authHeaders { getRequest.setValue(value, forHTTPHeaderField: key) }
        getRequest.timeoutInterval = 8

        let (shaData, shaResponse) = try await session.data(for: getRequest)
        guard let http = shaResponse as? HTTPURLResponse, http.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: shaData) as? [String: Any],
              let sha = json["sha"] as? String else {
            throw GitHubError.uploadFailed("无法获取文件信息")
        }

        // 2. 删除文件
        let deleteUrl = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/contents/\(path)")!
        var deleteRequest = URLRequest(url: deleteUrl)
        deleteRequest.httpMethod = "DELETE"
        for (key, value) in authHeaders { deleteRequest.setValue(value, forHTTPHeaderField: key) }
        deleteRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": message,
            "sha": sha,
            "branch": branch,
        ]
        deleteRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, deleteResponse) = try await session.data(for: deleteRequest)
        guard let http = deleteResponse as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw GitHubError.uploadFailed("文件删除失败")
        }
    }

    // MARK: - Pull Request

    private func createPullRequest(from headBranch: String, to baseBranch: String, title: String, body: String) async throws -> String {
        let url = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/pulls")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in authHeaders { request.setValue(value, forHTTPHeaderField: key) }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prBody: [String: Any] = ["title": title, "body": body, "head": headBranch, "base": baseBranch]
        request.httpBody = try JSONSerialization.data(withJSONObject: prBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw GitHubError.uploadFailed("创建 PR 失败: \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prURL = json["html_url"] as? String else {
            throw GitHubError.invalidResponse
        }
        return prURL
    }

    // MARK: - CDN URL

    func cdnURL(for path: String) -> String {
        "\(cdnBase)/\(repoOwner)/\(repoName)@main/\(path)"
    }

    func rawURL(for path: String) -> String {
        "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/main/\(path)"
    }

    // MARK: - Get Contents

    func getContents(path: String) async throws -> [[String: Any]] {
        let url = URL(string: "\(apiBase)/repos/\(repoOwner)/\(repoName)/contents/\(path)")!
        var request = URLRequest(url: url)
        for (key, value) in authHeaders { request.setValue(value, forHTTPHeaderField: key) }
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)
        // 404/403 等错误直接返回空，不继续解析
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return []
        }
        guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return entries
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "未授权，请先登录 GitHub"
        case .invalidResponse: return "无效的服务器响应"
        case .uploadFailed(let msg): return msg
        }
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    private static let service = "com.geminimortal.MacIsland"

    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
