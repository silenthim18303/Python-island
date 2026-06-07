//
//  UpdateManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/7.
//

import Foundation
import AppKit
import Combine

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
    case upToDate
    case error(String)

    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate):
            return true
        case (.available(let v1, _, _), .available(let v2, _, _)):
            return v1 == v2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

/// 自定义更新管理器
@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    private let repoOwner = "MacIsland"
    private let repoName = "MacIsland"
    private let apiURL = "https://api.github.com/repos/MacIsland/MacIsland/releases/latest"

    @Published var status: UpdateStatus = .idle
    @Published var isChecking = false

    private init() {}

    /// 检查更新
    func checkForUpdates() async {
        guard !isChecking else { return }

        isChecking = true
        status = .checking

        do {
            let release = try await fetchLatestRelease()
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"

            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")

            if isNewerVersion(latestVersion, than: currentVersion) {
                // 找到 DMG 下载链接
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

    /// 获取最新 Release
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

    /// 比较版本号
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

    /// 下载并安装更新
    func downloadAndInstall(url: String) async {
        guard let downloadURL = URL(string: url) else { return }

        // 打开下载链接让用户手动安装
        NSWorkspace.shared.open(downloadURL)
    }

    /// 打开 GitHub Releases 页面
    func openReleasesPage() {
        if let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}
