//
//  SettingsCatalog.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/5.
//

import SwiftUI

// MARK: - Settings Catalog

/// 设置目录 — 分类 + 条目元数据的单一数据源。
/// 内联面板（深色）与原生偏好窗口共用此目录，保证分类一致、
/// 搜索逻辑只写一次、描述/提示文案集中维护。
enum SettingsCatalog {

    // MARK: - Search

    /// 搜索结果：命中的分类，及该分类下命中的条目（条目为空表示分类标题命中）
    struct SearchHit: Identifiable {
        let category: SettingsCategory
        let items: [SettingItemMeta]
        var id: SettingsCategory { category }
    }

    /// 按关键词过滤分类与条目。空查询返回全部分类（条目为空）。
    static func search(_ rawQuery: String) -> [SearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return SettingsCategory.allCases.map { SearchHit(category: $0, items: []) }
        }
        var hits: [SearchHit] = []
        for category in SettingsCategory.allCases {
            let items = SettingItemMeta.all
                .filter { $0.category == category && $0.matches(query) }
            // 分类标题/关键词本身命中时，也算命中（条目交由面板自行展开）
            if category.matches(query) || !items.isEmpty {
                hits.append(SearchHit(category: category, items: items))
            }
        }
        return hits
    }
}

// MARK: - Settings Category

/// 设置分类 — 取代原先「通用」一个标签塞满全部的结构。
enum SettingsCategory: String, CaseIterable, Identifiable {
    case appearance   // 外观
    case wallpaper    // 壁纸
    case animation    // 动画
    case clipboard    // 剪贴板
    case music        // 音乐与歌词
    case weather      // 天气
    case community    // 社区
    case shortcuts    // 快捷键
    case about        // 关于

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance: return "外观"
        case .wallpaper:  return "壁纸"
        case .animation:  return "动画"
        case .clipboard:  return "剪贴板"
        case .music:      return "音乐与歌词"
        case .weather:    return "天气"
        case .community:  return "社区"
        case .shortcuts:  return "快捷键"
        case .about:      return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .appearance: return "paintbrush"
        case .wallpaper:  return "photo"
        case .animation:  return "wand.and.rays"
        case .clipboard:  return "doc.on.clipboard"
        case .music:      return "music.note"
        case .weather:    return "cloud.sun"
        case .community:  return "person.2"
        case .shortcuts:  return "command"
        case .about:      return "info.circle"
        }
    }

    /// 搜索关键词（含中英文别名），用于分类标题级匹配
    private var keywords: [String] {
        switch self {
        case .appearance: return ["外观", "透明度", "语言", "自启", "appearance", "opacity", "language"]
        case .wallpaper:  return ["壁纸", "存储", "路径", "wallpaper", "path"]
        case .animation:  return ["动画", "弹簧", "速度", "animation", "spring", "speed"]
        case .clipboard:  return ["剪贴板", "链接", "url", "黑名单", "clipboard", "link"]
        case .music:      return ["音乐", "歌词", "lyrics", "netease", "music"]
        case .weather:    return ["天气", "城市", "weather", "city", "location"]
        case .community:  return ["社区", "上传", "用户名", "community", "upload"]
        case .shortcuts:  return ["快捷键", "热键", "shortcut", "hotkey", "key"]
        case .about:      return ["关于", "版本", "about", "version"]
        }
    }

    func matches(_ loweredQuery: String) -> Bool {
        if title.lowercased().contains(loweredQuery) { return true }
        return keywords.contains { $0.lowercased().contains(loweredQuery) }
    }
}

// MARK: - Setting Item Metadata

/// 单个设置项的元数据 — 标题、说明、输入提示，供两个面板统一文案与搜索。
struct SettingItemMeta: Identifiable {
    /// 稳定标识（搜索结果定位用）
    let key: String
    let category: SettingsCategory
    /// 设置项标题（如「灵动岛透明度」）
    let title: String
    /// 一句话说明，渲染在标题下方的小字
    let description: String
    /// 输入框 placeholder / 示例提示；无输入控件时为空
    let hint: String
    /// 额外搜索关键词
    let extraKeywords: [String]

    init(_ key: String,
         _ category: SettingsCategory,
         title: String,
         description: String,
         hint: String = "",
         keywords: [String] = []) {
        self.key = key
        self.category = category
        self.title = title
        self.description = description
        self.hint = hint
        self.extraKeywords = keywords
    }

    var id: String { key }

    func matches(_ loweredQuery: String) -> Bool {
        if title.lowercased().contains(loweredQuery) { return true }
        if description.lowercased().contains(loweredQuery) { return true }
        return extraKeywords.contains { $0.lowercased().contains(loweredQuery) }
    }

    /// 按 key 取元数据（找不到返回 nil，面板可据此退化为仅标题）
    static func meta(_ key: String) -> SettingItemMeta? {
        all.first { $0.key == key }
    }

    // MARK: - Catalog

    static let all: [SettingItemMeta] = [
        // 外观
        .init("appearanceMode", .appearance,
              title: "外观模式", description: "切换深色/浅色/跟随系统主题。",
              keywords: ["theme", "dark", "light", "深色", "浅色", "主题"]),
        .init("accentColor", .appearance,
              title: "强调色", description: "自定义界面强调色。",
              keywords: ["accent", "color", "颜色", "强调色"]),
        .init("language", .appearance,
              title: "语言", description: "切换界面显示语言，重启后完全生效。",
              keywords: ["language", "中文", "english"]),
        .init("launchAtLogin", .appearance,
              title: "开机自启动", description: "登录系统后自动启动 MacIsland。",
              keywords: ["login", "startup", "自启"]),
        .init("islandOpacity", .appearance,
              title: "灵动岛透明度", description: "调整灵动岛整体不透明度（10%–100%）。",
              keywords: ["opacity", "透明"]),
        .init("wallpaperOpacity", .appearance,
              title: "壁纸透明度", description: "独立于灵动岛整体透明度的壁纸不透明度。",
              keywords: ["opacity", "壁纸", "透明"]),

        // 壁纸
        .init("customWallpaperPath", .wallpaper,
              title: "存储路径", description: "自定义壁纸缓存目录，留空使用默认位置。",
              hint: "默认路径",
              keywords: ["path", "目录", "缓存"]),

        // 动画
        .init("animationSpeed", .animation,
              title: "动画速度", description: "灵动岛展开/折叠的过渡时长。",
              keywords: ["speed", "速度"]),
        .init("springAnimation", .animation,
              title: "弹簧动画", description: "启用更有弹性的弹簧过渡曲线。",
              keywords: ["spring", "弹簧"]),

        // 剪贴板
        .init("clipboardEnabled", .clipboard,
              title: "链接检测", description: "复制链接时在灵动岛快速提示。",
              keywords: ["link", "检测"]),
        .init("clipboardUrlDetectMode", .clipboard,
              title: "URL 检测模式", description: "选择被识别为链接的 URL 形式。",
              keywords: ["url", "http", "https", "domain"]),
        .init("blacklistedDomains", .clipboard,
              title: "域名黑名单", description: "命中黑名单的域名不会触发链接提示。",
              hint: "example.com",
              keywords: ["blacklist", "黑名单", "domain"]),

        // 音乐与歌词
        .init("preferredLyricsSource", .music,
              title: "歌词源", description: "优先使用的歌词数据来源。",
              keywords: ["lyrics", "netease", "网易", "qq", "酷狗", "lrclib"]),

        // 天气
        .init("weatherManualCity", .weather,
              title: "手动城市", description: "指定城市名，留空则自动定位。",
              hint: "自动定位",
              keywords: ["city", "城市", "定位"]),
        .init("weatherManualLocationID", .weather,
              title: "Location ID", description: "和风天气城市 ID，配合手动城市使用。",
              hint: "101010100",
              keywords: ["location", "id", "和风"]),

        // 社区
        .init("communityUploadUsername", .community,
              title: "上传用户名", description: "上传社区壁纸时显示的作者名。",
              hint: "设置用户名",
              keywords: ["username", "用户名", "上传"]),

        // 快捷键
        .init("hotkeyBindings", .shortcuts,
              title: "全局快捷键", description: "自定义显示/播放控制等全局热键。",
              keywords: ["hotkey", "shortcut", "热键"]),
    ]
}
