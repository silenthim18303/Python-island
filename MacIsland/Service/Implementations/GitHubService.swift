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

// MARK: - URL Session Delegate (安全 TLS 验证)

/// 安全的 TLS 验证策略：
/// 1. 先用系统默认验证（标准 CA 证书链）
/// 2. 失败时检查证书是否被用户手动信任（如 Clash/Charles 的 CA 证书）
/// 3. 都不满足则拒绝连接
private class GitHubSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host
        let isGitHubDomain = host.hasSuffix("github.com")
            || host.hasSuffix("githubusercontent.com")
            || host.hasSuffix("github.io")

        // 非 GitHub 域名走系统默认验证
        guard isGitHubDomain else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 第一步：系统默认验证（标准 CA 证书链）
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        // 第二步：系统验证失败 → 检查是否有用户手动信任的根证书
        // （兼容 Clash/Charles 等代理工具的 MITM 证书）
        if isCertificateTrustedByUser(trust) {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }

        // 第三步：都不满足 → 拒绝连接（防止 MITM 攻击）
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// 检查证书链是否包含用户手动信任的根证书
    /// 用户在钥匙串中手动安装并信任的 CA 证书会被系统标记为 kSecTrustSettingsResultTrustRoot
    private func isCertificateTrustedByUser(_ trust: SecTrust) -> Bool {
        // 获取证书链
        let certCount = SecTrustGetCertificateCount(trust)
        guard certCount > 0 else { return false }

        // kSecTrustSettingsResult 对应的值:
        // kSecTrustSettingsResultTrustRoot = 3 (完全信任的根证书)
        // kSecTrustSettingsResultProceed = 1 (显式允许)
        let kSecTrustResultTrustRoot: UInt32 = 3
        let kSecTrustResultProceed: UInt32 = 1

        // 检查每一级证书是否被用户显式信任
        for i in 0..<certCount {
            guard let cert = SecTrustGetCertificateAtIndex(trust, i) else { continue }

            // 检查 user 级别的信任设置
            if isCertTrusted(cert, domain: .user, trustRoot: kSecTrustResultTrustRoot, proceed: kSecTrustResultProceed) {
                return true
            }
            // 检查 admin 级别
            if isCertTrusted(cert, domain: .admin, trustRoot: kSecTrustResultTrustRoot, proceed: kSecTrustResultProceed) {
                return true
            }
            // 检查 system 级别
            if isCertTrusted(cert, domain: .system, trustRoot: kSecTrustResultTrustRoot, proceed: kSecTrustResultProceed) {
                return true
            }
        }

        return false
    }

    /// 检查指定证书在指定信任域是否被信任
    private func isCertTrusted(_ cert: SecCertificate, domain: SecTrustSettingsDomain,
                               trustRoot: UInt32, proceed: UInt32) -> Bool {
        var trustSettings: CFArray?
        let status = SecTrustSettingsCopyTrustSettings(cert, domain, &trustSettings)
        guard status == errSecSuccess, let settings = trustSettings as? [[String: Any]] else {
            return false
        }
        for setting in settings {
            if let result = setting[kSecTrustSettingsResult as String] as? UInt32 {
                if result == trustRoot || result == proceed {
                    return true
                }
            }
        }
        return false
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
    private let builtinClientID = Secrets.githubClientID
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
        SecureStorage.load(key: "github_token")
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
            "scope": "public_repo",
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
        SecureStorage.save(key: "github_token", value: token)
        isAuthenticated = true
    }

    func removeToken() {
        SecureStorage.delete(key: "github_token")
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
            throw GitHubError.uploadFailed(L10n.errorGitHubSize)
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
                    throw GitHubError.uploadFailed(L10n.errorGitHubRepo)
                }
                if http.statusCode == 403 {
                    let body = String(data: repoData, encoding: .utf8) ?? ""
                    throw GitHubError.uploadFailed(L10n.errorGitHubPermission)
                }
                if !(200...299).contains(http.statusCode) {
                    throw GitHubError.uploadFailed("\(L10n.errorGitHubHTTP) \(http.statusCode)")
                }
            }
        } catch let error as GitHubError {
            throw error
        } catch {
            throw GitHubError.uploadFailed("\(L10n.errorGitHubNetwork): \(error.localizedDescription)")
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
            body: "User **\(username)** uploaded wallpaper **\(wallpaperName)**\n\nType: \(isVideo ? L10n.wallpaperVideo : L10n.wallpaperImage)"
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
            body: "User **\(username)** deleted wallpaper **\(wallpaperName)**"
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
            throw GitHubError.uploadFailed(L10n.errorGitHubBranch)
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
                throw GitHubError.uploadFailed("\(branch) \(L10n.errorGitHubBranchNotFound)")
            }
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["commit"] as? [String: Any],
              let sha = commit["sha"] as? String else {
            print("[GitHub] SHA 解析失败: \(String(data: data, encoding: .utf8) ?? "")")
            throw GitHubError.uploadFailed(L10n.errorGitHubBranchInfo)
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
            throw GitHubError.uploadFailed(L10n.errorGitHubFileCreate)
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
            throw GitHubError.uploadFailed(L10n.errorGitHubFileInfo)
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
            throw GitHubError.uploadFailed(L10n.errorGitHubFileDelete)
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
            throw GitHubError.uploadFailed("\(L10n.errorGitHubPR): \(errorBody)")
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

// MARK: - Keychain Helper (已迁移至 SecureStorage)

// KeychainHelper 已废弃，统一使用 SecureStorage
