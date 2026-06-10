//
//  UpdateManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/7.
//

import Foundation
import AppKit
import Combine
import CryptoKit

/// GitHub Release 响应模型
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

/// GitHub Asset 模型
struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// 更新状态
enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(version: String, downloadUrl: String, releaseNotes: String?)
    case downloading(progress: Double)
    case verifying
    case upToDate
    case error(String)

    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate),
             (.verifying, .verifying):
            return true
        case (.available(let v1, _, _), .available(let v2, _, _)):
            return v1 == v2
        case (.downloading(let p1), .downloading(let p2)):
            return p1 == p2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

/// 自定义更新管理器 — SHA256 哈希验证
@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let repoOwner = "MacIsland"
    private let repoName = "MacIsland"
    private let apiURL = "https://api.github.com/repos/MacIsland/MacIsland/releases/latest"

    @Published var status: UpdateStatus = .idle
    @Published var isChecking = false

    private var downloadTask: Task<Void, Never>?
    private let fileManager = FileManager.default

    private init() {}

    // MARK: - 检查更新

    func checkForUpdates() async {
        guard !isChecking else { return }

        isChecking = true
        status = .checking

        do {
            let release = try await fetchLatestRelease()
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")

            if isNewerVersion(latestVersion, than: currentVersion) {
                if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                    status = .available(
                        version: latestVersion,
                        downloadUrl: dmgAsset.browserDownloadUrl,
                        releaseNotes: release.body
                    )
                } else {
                    status = .available(
                        version: latestVersion,
                        downloadUrl: release.htmlUrl,
                        releaseNotes: release.body
                    )
                }
            } else {
                status = .upToDate
            }
        } catch {
            status = .error(error.localizedDescription)
        }

        isChecking = false
    }

    // MARK: - 获取最新 Release

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: apiURL) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    // MARK: - 下载并安装（带 SHA256 验证）

    func downloadAndInstall(url: String) async {
        guard let downloadURL = URL(string: url) else {
            status = .error("无效的下载地址")
            return
        }

        // 获取 release body 中的 SHA256
        let expectedHash = await fetchExpectedSHA256()

        // 下载到临时目录
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("MacIslandUpdate")
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileName = downloadURL.lastPathComponent
        let tempFile = tempDir.appendingPathComponent(fileName)

        // 如果文件已存在且哈希匹配，直接使用
        if fileManager.fileExists(atPath: tempFile.path) {
            if let hash = expectedHash, verifySHA256(file: tempFile, expected: hash) {
                await installDMG(at: tempFile)
                return
            }
            try? fileManager.removeItem(at: tempFile)
        }

        // 下载文件
        do {
            let downloadedFile = try await downloadFile(from: downloadURL, to: tempFile)

            // SHA256 验证
            if let hash = expectedHash {
                status = .verifying
                if !verifySHA256(file: downloadedFile, expected: hash) {
                    try? fileManager.removeItem(at: downloadedFile)
                    status = .error("文件校验失败，可能被篡改。已拒绝安装。")
                    return
                }
            }

            // 验证通过，安装
            await installDMG(at: downloadedFile)
        } catch {
            status = .error("下载失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 下载文件（带进度）

    private func downloadFile(from url: URL, to destination: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        // 移动到目标位置
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempURL, to: destination)

        status = .downloading(progress: 1.0)
        return destination
    }

    // MARK: - SHA256 验证

    /// 从 release body 提取预期的 SHA256
    private func fetchExpectedSHA256() async -> String? {
        do {
            let release = try await fetchLatestRelease()
            guard let body = release.body else { return nil }
            return extractSHA256(from: body)
        } catch {
            return nil
        }
    }

    /// 从 release body 文本中提取 SHA256
    /// 格式: sha256:abc123... 或 SHA256:abc123... 或 sha256=abc123...
    func extractSHA256(from text: String) -> String? {
        let patterns = [
            #"sha256[:\s=]+([a-fA-F0-9]{64})"#,
            #"SHA256[:\s=]+([a-fA-F0-9]{64})"#,
            #"`([a-fA-F0-9]{64})`"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range]).lowercased()
            }
        }
        return nil
    }

    /// 验证文件 SHA256
    func verifySHA256(file: URL, expected: String) -> Bool {
        guard let data = try? Data(contentsOf: file) else { return false }
        let hash = SHA256.hash(data: data)
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        return hashString == expected.lowercased()
    }

    // MARK: - 安装 DMG

    private func installDMG(at dmgURL: URL) async {
        // 挂载 DMG
        let mountResult = shell("/usr/bin/hdiutil", args: ["attach", dmgURL.path, "-nobrowse", "-quiet"])

        if mountResult.exitCode != 0 {
            status = .error("挂载 DMG 失败")
            return
        }

        // 找到挂载点
        let mountPoint = mountResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !mountPoint.isEmpty else {
            status = .error("无法找到挂载点")
            return
        }

        // 找到 .app
        let appPath = findApp(in: mountPoint)

        guard let app = appPath else {
            _ = shell("/usr/bin/hdiutil", args: ["detach", mountPoint, "-quiet"])
            status = .error("DMG 中未找到应用")
            return
        }

        // 复制到 Applications
        let appName = (app as NSString).lastPathComponent
        let destPath = "/Applications/\(appName)"

        // 如果已存在，先删除
        if fileManager.fileExists(atPath: destPath) {
            try? fileManager.removeItem(atPath: destPath)
        }

        do {
            try fileManager.copyItem(atPath: app, toPath: destPath)
            _ = shell("/usr/bin/hdiutil", args: ["detach", mountPoint, "-quiet"])

            // 清理临时文件
            try? fileManager.removeItem(at: dmgURL.deletingLastPathComponent())

            status = .idle

            // 提示用户并重启
            await showRestartAlert(appPath: destPath)
        } catch {
            _ = shell("/usr/bin/hdiutil", args: ["detach", mountPoint, "-quiet"])
            status = .error("安装失败: \(error.localizedDescription)")
        }
    }

    /// 在挂载目录中查找 .app
    private func findApp(in directory: String) -> String? {
        guard let items = try? fileManager.contentsOfDirectory(atPath: directory) else { return nil }
        for item in items {
            if item.hasSuffix(".app") {
                return (directory as NSString).appendingPathComponent(item)
            }
        }
        return nil
    }

    /// 显示重启提示
    private func showRestartAlert(appPath: String) async {
        let alert = NSAlert()
        alert.messageText = "更新已安装"
        alert.informativeText = "新版本已安装到 /Applications。是否立即重启应用？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "重启")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 重启应用
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-n", appPath]
            try? task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Shell 执行

    private func shell(_ path: String, args: [String]) -> (output: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, task.terminationStatus)
        } catch {
            return ("", -1)
        }
    }

    // MARK: - 版本比较

    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let newParts = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentParts = currentVersion.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(newParts.count, currentParts.count)

        for i in 0..<maxLength {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart {
                return true
            } else if newPart < currentPart {
                return false
            }
        }

        return false
    }

    /// 打开 GitHub Releases 页面
    func openReleasesPage() {
        if let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}
