//
//  WallpaperItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Wallpaper Source

/// 壁纸来源
enum WallpaperSource: String, Codable, CaseIterable {
    case local = "本地"
    case community = "社区"
}

// MARK: - Wallpaper Item

/// 壁纸数据模型
struct WallpaperItem: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var localPath: String
    var isVideo: Bool
    var source: WallpaperSource
    var author: String
    var isActive: Bool
    var thumbnailURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        localPath: String,
        isVideo: Bool = false,
        source: WallpaperSource = .local,
        author: String = "",
        isActive: Bool = false,
        thumbnailURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.localPath = localPath
        self.isVideo = isVideo
        self.source = source
        self.author = author
        self.isActive = isActive
        self.thumbnailURL = thumbnailURL
    }

    /// 本地文件是否存在
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: localPath)
    }

    /// 文件 URL
    var fileURL: URL? {
        URL(fileURLWithPath: localPath)
    }
}

// MARK: - Community Wallpaper

/// 社区壁纸（从 GitHub API 获取）
struct CommunityWallpaper: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let author: String
    let imageURL: String
    let thumbnailURL: String
    let isVideo: Bool
    var isDownloaded: Bool = false
}
