//
//  WallpaperStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Wallpaper Store

/// 壁纸状态管理 — 本地持久化 + GitHub 社区
@MainActor
final class WallpaperStore: ObservableObject {
    static let shared = WallpaperStore()

    @Published var wallpapers: [WallpaperItem] = [] {
        didSet { save() }
    }
    @Published var activeWallpaper: WallpaperItem? {
        didSet {
            // 同步 isActive 标记
            for i in wallpapers.indices {
                wallpapers[i].isActive = wallpapers[i].id == activeWallpaper?.id
            }
            // 持久化当前壁纸 ID
            defaults.set(activeWallpaper?.id.uuidString, forKey: Keys.activeWallpaperID)
        }
    }
    @Published var communityWallpapers: [CommunityWallpaper] = []
    @Published var isLoadingCommunity = false
    @Published var communityError: String?

    /// 私有壁纸集合（name+author），不对外展示
    @Published var privateWallpapers: Set<String> = []

    private let defaults = UserDefaults.standard
    private let wallpaperKey = "wallpaperItems"
    private let activeWallpaperIDKey = "activeWallpaperID"
    private var scopedCustomDirectory: URL?
    private var isAccessingScopedCustomDirectory = false

    private enum Keys {
        static let wallpaperItems = "wallpaperItems"
        static let activeWallpaperID = "activeWallpaperID"
    }

    // MARK: - 存储目录

    /// 基础存储目录（支持自定义路径）
    private var baseDirectory: URL {
        if let url = AppSettings.shared.customWallpaperDirectoryURL {
            startAccessingCustomDirectoryIfNeeded(url)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        stopAccessingCustomDirectoryIfNeeded()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MacIsland/Wallpapers", isDirectory: true)
    }

    private func startAccessingCustomDirectoryIfNeeded(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        if scopedCustomDirectory?.standardizedFileURL == standardizedURL,
           isAccessingScopedCustomDirectory {
            return
        }

        stopAccessingCustomDirectoryIfNeeded()
        isAccessingScopedCustomDirectory = standardizedURL.startAccessingSecurityScopedResource()
        scopedCustomDirectory = standardizedURL
    }

    private func stopAccessingCustomDirectoryIfNeeded() {
        guard isAccessingScopedCustomDirectory else {
            scopedCustomDirectory = nil
            return
        }

        scopedCustomDirectory?.stopAccessingSecurityScopedResource()
        scopedCustomDirectory = nil
        isAccessingScopedCustomDirectory = false
    }

    /// 本地壁纸目录
    var localDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("local", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 社区下载壁纸目录
    var communityDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("community", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 上传壁纸目录（待分享）
    var uploadDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("uploaded", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 兼容旧路径（迁移用）
    var storageDirectory: URL { baseDirectory }

    private init() {
        wallpapers = Self.load(defaults: defaults)
        // 恢复当前壁纸
        if let activeIDString = defaults.string(forKey: Keys.activeWallpaperID),
           let activeID = UUID(uuidString: activeIDString),
           let item = wallpapers.first(where: { $0.id == activeID && $0.fileExists }) {
            activeWallpaper = item
        }
        // 加载私有壁纸列表
        if let data = defaults.data(forKey: "privateWallpapers"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            privateWallpapers = Set(decoded)
        }
    }

    // MARK: - 本地壁纸管理

    /// 从本地文件添加壁纸
    func addWallpaper(from sourceURL: URL) {
        let isAccessingSource = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = sourceURL.lastPathComponent
        let destURL = localDirectory.appendingPathComponent(fileName)

        // 复制文件到本地壁纸目录
        try? FileManager.default.removeItem(at: destURL)
        guard (try? FileManager.default.copyItem(at: sourceURL, to: destURL)) != nil else { return }

        let isVideo = ["mp4", "mov", "m4v"].contains(sourceURL.pathExtension.lowercased())
        let name = sourceURL.deletingPathExtension().lastPathComponent

        let item = WallpaperItem(
            name: name,
            localPath: destURL.path,
            isVideo: isVideo,
            source: .local
        )
        wallpapers.append(item)
    }

    /// 设置当前壁纸
    func setActive(_ item: WallpaperItem) {
        // 取消其他壁纸的激活状态
        for i in wallpapers.indices {
            wallpapers[i].isActive = wallpapers[i].id == item.id
        }
        activeWallpaper = item
    }

    /// 关闭壁纸（回到默认背景）
    func clearActiveWallpaper() {
        for i in wallpapers.indices {
            wallpapers[i].isActive = false
        }
        activeWallpaper = nil
    }

    /// 删除壁纸
    func deleteWallpaper(_ item: WallpaperItem) {
        if activeWallpaper?.id == item.id {
            activeWallpaper = nil
        }
        // 删除本地文件
        try? FileManager.default.removeItem(atPath: item.localPath)
        // 删除缩略图
        if let thumbPath = item.thumbnailURL {
            try? FileManager.default.removeItem(atPath: thumbPath)
        }
        wallpapers.removeAll { $0.id == item.id }

        // 社区壁纸：重置已下载标记，允许重新下载
        if item.source == .community {
            for i in communityWallpapers.indices {
                if communityWallpapers[i].name == item.name && communityWallpapers[i].author == item.author {
                    communityWallpapers[i].isDownloaded = false
                }
            }
        }
    }

    // MARK: - 社区壁纸

    /// 从 GitHub 获取社区壁纸列表（使用 jsDelivr CDN）
    func fetchCommunityWallpapers() async {
        isLoadingCommunity = true
        communityError = nil
        defer { isLoadingCommunity = false }

        let github = GitHubService.shared
        let cdnBase = "https://cdn.jsdelivr.net/gh/MacIsland/wallpaper4MacIsland@main"

        do {
            let entries = try await github.getContents(path: "")
            print("[Wallpaper] 仓库根目录: \(entries.count) 个条目")
            for entry in entries {
                print("[Wallpaper]   - \(entry["name"] ?? "?") (\(entry["type"] ?? "?"))")
            }

            var wallpapers: [CommunityWallpaper] = []

            for entry in entries {
                guard let type = entry["type"] as? String, type == "dir",
                      let userName = entry["name"] as? String else { continue }

                let userEntries = try await github.getContents(path: userName)
                print("[Wallpaper] \(userName)/: \(userEntries.count) 个条目")

                for subEntry in userEntries {
                    guard let subType = subEntry["type"] as? String, subType == "dir",
                          let wpName = subEntry["name"] as? String else { continue }

                    let wpEntries = try await github.getContents(path: "\(userName)/\(wpName)")
                    print("[Wallpaper]   \(userName)/\(wpName)/: \(wpEntries.count) 个文件")

                    var imageURL = ""
                    var thumbURL = ""
                    var isVideo = false

                    for file in wpEntries {
                        guard let fileName = file["name"] as? String else { continue }
                        let ext = (fileName as NSString).pathExtension.lowercased()
                        let filePath = "\(userName)/\(wpName)/\(fileName)"

                        if ["jpg", "jpeg", "png", "webp"].contains(ext) && !isVideo {
                            if fileName == "thumbnail.jpg" || fileName == "thumbnail.png" {
                                thumbURL = "\(cdnBase)/\(filePath)"
                            } else {
                                imageURL = "\(cdnBase)/\(filePath)"
                                if thumbURL.isEmpty { thumbURL = imageURL }
                            }
                        }
                        if ["mp4", "mov", "m4v"].contains(ext) {
                            isVideo = true
                            imageURL = "\(cdnBase)/\(filePath)"
                        }
                    }

                    if !imageURL.isEmpty {
                        wallpapers.append(CommunityWallpaper(
                            name: wpName,
                            author: userName,
                            imageURL: imageURL,
                            thumbnailURL: thumbURL.isEmpty ? imageURL : thumbURL,
                            isVideo: isVideo
                        ))
                    }
                }
            }

            communityWallpapers = wallpapers
        } catch {
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorCannotFindHost {
                communityError = L10n.errorGitHubRepo
            } else {
                communityError = "\(L10n.error): \(error.localizedDescription)"
            }
        }
    }

    /// 下载社区壁纸到本地
    func downloadCommunityWallpaper(_ community: CommunityWallpaper) async {
        guard let url = URL(string: community.imageURL) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ext = (community.imageURL as NSString).pathExtension
            let fileName = "\(community.author)_\(community.name).\(ext)"
            let destURL = communityDirectory.appendingPathComponent(fileName)

            try data.write(to: destURL)

            let isVideo = ["mp4", "mov", "m4v"].contains(ext.lowercased())
            let item = WallpaperItem(
                name: community.name,
                localPath: destURL.path,
                isVideo: isVideo,
                source: .community,
                author: community.author
            )
            wallpapers.append(item)

            // 标记已下载
            if let index = communityWallpapers.firstIndex(where: { $0.id == community.id }) {
                communityWallpapers[index].isDownloaded = true
            }
        } catch {
            print("[Wallpaper] 下载失败: \(error)")
        }
    }

    // MARK: - 私有壁纸管理

    /// 生成壁纸唯一标识
    private func wallpaperKey(_ community: CommunityWallpaper) -> String {
        "\(community.author)/\(community.name)"
    }

    /// 检查壁纸是否为私有
    func isWallpaperPrivate(_ community: CommunityWallpaper) -> Bool {
        privateWallpapers.contains(wallpaperKey(community))
    }

    /// 切换壁纸私有状态
    func toggleWallpaperPrivacy(_ community: CommunityWallpaper) {
        let key = wallpaperKey(community)
        if privateWallpapers.contains(key) {
            privateWallpapers.remove(key)
        } else {
            privateWallpapers.insert(key)
        }
        savePrivateWallpapers()
    }

    private func savePrivateWallpapers() {
        if let data = try? JSONEncoder().encode(Array(privateWallpapers)) {
            defaults.set(data, forKey: "privateWallpapers")
        }
    }

    // MARK: - 删除社区壁纸

    /// 删除社区壁纸（通过 GitHub PR）
    func deleteCommunityWallpaper(_ community: CommunityWallpaper) async -> UploadResult {
        let github = GitHubService.shared
        guard github.isAuthenticated else {
            print("[Wallpaper] 删除失败: 未登录 GitHub")
            return .failure(L10n.errorGitHubLogin)
        }

        // 移除本地已下载的文件
        if let localItem = wallpapers.first(where: { $0.name == community.name && $0.author == community.author }) {
            deleteWallpaper(localItem)
        }

        // 推断文件扩展名
        let ext = community.isVideo ? "mp4" : "jpg"
        print("[Wallpaper] 调用 GitHub 删除: \(community.author)/\(community.name)/wallpaper.\(ext)")

        do {
            let prURL = try await github.deleteWallpaper(
                username: community.author,
                wallpaperName: community.name,
                fileExtension: ext
            )
            print("[Wallpaper] GitHub 删除成功，PR: \(prURL)")
            // 从列表中移除
            communityWallpapers.removeAll { $0.id == community.id }
            return .success(prURL: prURL)
        } catch {
            print("[Wallpaper] GitHub 删除失败: \(error)")
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - 上传到社区（通过 GitHub PR 审核）

    /// 上传结果
    enum UploadResult {
        case success(prURL: String)
        case failure(String)
    }

    func uploadCommunityWallpaper(from sourceURL: URL, username: String) async -> UploadResult {
        let github = GitHubService.shared

        guard github.isAuthenticated else {
            return .failure(L10n.errorGitHubToken)
        }

        // 文件大小校验
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
              let fileSize = attrs[.size] as? Int64 else {
            return .failure(L10n.error)
        }
        guard fileSize <= GitHubService.uploadFilesizeLimit else {
            return .failure(L10n.errorGitHubSize)
        }

        let name = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.lowercased()
        let isVideo = ["mp4", "mov", "m4v"].contains(ext)

        let fileData: Data
        if isVideo {
            // 视频：直接读取（无法压缩）
            guard let data = try? Data(contentsOf: sourceURL) else {
                return .failure(L10n.errorGitHubVideo)
            }
            fileData = data
        } else {
            // 图片：压缩后再上传，大幅减少内存和传输量
            guard let compressed = Self.compressImage(at: sourceURL, maxDimension: 2048, quality: 0.8) else {
                return .failure(L10n.errorGitHubCompress)
            }
            fileData = compressed
        }

        do {
            let prURL = try await github.uploadWallpaper(
                username: username,
                wallpaperName: name,
                data: fileData,
                isVideo: isVideo
            )
            return .success(prURL: prURL)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - 图片压缩

    /// 压缩图片：缩放到 maxDimension 以内，按 quality 压缩为 JPEG
    /// 返回压缩后的 Data，失败返回 nil
    static func compressImage(at url: URL, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        // 读取原始尺寸
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight as String] as? CGFloat else {
            // 无法读取尺寸，直接读取原图
            return try? Data(contentsOf: url)
        }

        // 如果已经很小，直接返回原图数据
        let maxSize = max(width, height)
        if maxSize <= maxDimension {
            return try? Data(contentsOf: url)
        }

        // 计算缩放比例
        let scale = maxDimension / maxSize
        let targetWidth = Int(width * scale)
        let targetHeight = Int(height * scale)

        // 缩放
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return try? Data(contentsOf: url)
        }

        // 压缩为 JPEG
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: targetWidth, height: targetHeight))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return nil
        }

        let originalSize = (try? Data(contentsOf: url).count) ?? 0
        let compressedSize = jpegData.count
        if originalSize > 0 {
            let ratio = Double(compressedSize) / Double(originalSize) * 100
            print("[Wallpaper] 图片压缩: \(originalSize / 1024)KB → \(compressedSize / 1024)KB (\(Int(ratio))%)")
        }

        return jpegData
    }

    // MARK: - 持久化

    private func save() {
        guard let data = try? JSONEncoder().encode(wallpapers) else { return }
        defaults.set(data, forKey: wallpaperKey)
    }

    private static func load(defaults: UserDefaults) -> [WallpaperItem] {
        guard let data = defaults.data(forKey: "wallpaperItems"),
              let decoded = try? JSONDecoder().decode([WallpaperItem].self, from: data)
        else { return [] }
        // 过滤掉文件已被删除的壁纸
        return decoded.filter { $0.fileExists }
    }
}
