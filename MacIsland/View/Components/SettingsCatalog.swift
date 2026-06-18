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
    case appearance    // 外观
    case wallpaper     // 壁纸
    case animation     // 动画
    case clipboard     // 剪贴板
    case weather       // 天气
    case notifications // 通知中心
    case community     // 社区
    case shortcuts     // 快捷键
    case voice         // 语音操作
    case ai            // AI 助手
    case stock          // 股票
    case about         // 关于

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:    return L10n.settingsAppearance
        case .wallpaper:     return L10n.wallpaperTitle
        case .animation:     return L10n.settingsAnimation
        case .clipboard:     return L10n.settingsClipboard
        case .weather:       return L10n.weatherTitle
        case .notifications: return L10n.notifCenter
        case .community:     return L10n.settingsCommunity
        case .shortcuts:     return L10n.settingsShortcuts
        case .voice:         return L10n.voiceTitle
        case .ai:            return L10n.aiTitle
        case .stock:         return L10n.stockTitle
        case .about:         return L10n.settingsAbout
        }
    }

    var systemImage: String {
        switch self {
        case .appearance:    return "paintbrush"
        case .wallpaper:     return "photo"
        case .animation:     return "wand.and.rays"
        case .clipboard:     return "doc.on.clipboard"
        case .weather:       return "cloud.sun"
        case .notifications: return "bell.badge"
        case .community:     return "person.2"
        case .shortcuts:     return "command"
        case .voice:         return "mic.fill"
        case .ai:            return "brain.head.profile"
        case .stock:         return "chart.line.uptrend.xyaxis"
        case .about:         return "info.circle"
        }
    }

    /// 搜索关键词（含中英文别名），用于分类标题级匹配
    private var keywords: [String] {
        switch self {
        case .appearance: return ["外观", "透明度", "语言", "自启", "深色", "浅色", "主题", "强调色", "颜色", "appearance", "opacity", "language", "theme", "dark", "light", "accent", "color"]
        case .wallpaper:  return ["壁纸", "存储", "路径", "wallpaper", "path"]
        case .animation:  return ["动画", "弹簧", "速度", "animation", "spring", "speed"]
        case .clipboard:  return ["剪贴板", "链接", "url", "黑名单", "clipboard", "link"]
        case .weather:       return ["天气", "城市", "weather", "city", "location"]
        case .notifications: return ["通知", "免打扰", "历史", "notification", "dnd", "mute"]
        case .community:     return ["社区", "上传", "用户名", "community", "upload"]
        case .shortcuts:  return ["快捷键", "热键", "shortcut", "hotkey", "key"]
        case .voice:      return ["语音", "声音", "麦克风", "voice", "speech", "microphone", "唤醒", "tts", "stt", "语音操作"]
        case .ai:         return ["AI", "人工智能", "Ollama", "OpenAI", "模型", "assistant", "artificial", "intelligence", "TTS", "STT", "语音合成", "语音识别"]
        case .stock:      return ["股票","股价","行情","stock","price","market"]
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

    /// 动态生成设置项元数据（使用当前语言）
    static var all: [SettingItemMeta] {
        [
            // 外观
            .init("appearanceMode", .appearance,
                  title: L10n.settingsTheme, description: L10n.descAppearanceMode,
                  keywords: ["theme", "dark", "light", "深色", "浅色", "主题"]),
            .init("accentColor", .appearance,
                  title: L10n.settingsAccentColor, description: L10n.descAccentColor,
                  keywords: ["accent", "color", "颜色", "强调色"]),
            .init("language", .appearance,
                  title: L10n.settingsLanguage, description: L10n.descLanguage,
                  keywords: ["language", "中文", "english", "日本語", "japanese"]),
            .init("launchAtLogin", .appearance,
                  title: L10n.settingsAutostart, description: L10n.descAutostart,
                  keywords: ["login", "startup", "自启"]),
            .init("islandOpacity", .appearance,
                  title: L10n.settingsOpacity, description: L10n.descIslandOpacity,
                  keywords: ["opacity", "透明"]),
            .init("wallpaperOpacity", .appearance,
                  title: L10n.settingsWallpaperOpacity, description: L10n.descWallpaperOpacity,
                  keywords: ["opacity", "壁纸", "透明"]),
            .init("widgetAppearance", .appearance,
                  title: L10n.settingsWidgetAppearance, description: L10n.descWidgetAppearance,
                  keywords: ["widget", "小组件", "深色", "浅色", "dark", "light"]),

            // 壁纸
            .init("customWallpaperPath", .wallpaper,
                  title: L10n.wallpaperPath, description: L10n.descWallpaperPath,
                  hint: L10n.wallpaperPathDefault,
                  keywords: ["path", "目录", "缓存"]),

            // 动画
            .init("animationSpeed", .animation,
                  title: L10n.settingsSpeed, description: L10n.descAnimationSpeed,
                  keywords: ["speed", "速度"]),
            .init("springAnimation", .animation,
                  title: L10n.settingsSpring, description: L10n.descSpringAnimation,
                  keywords: ["spring", "弹簧"]),

            // 剪贴板
            .init("clipboardEnabled", .clipboard,
                  title: L10n.settingsLinkDetect, description: L10n.descLinkDetect,
                  keywords: ["link", "检测"]),
            .init("clipboardUrlDetectMode", .clipboard,
                  title: L10n.settingsUrlMode, description: L10n.descUrlMode,
                  keywords: ["url", "http", "https", "domain"]),
            .init("blacklistedDomains", .clipboard,
                  title: L10n.settingsBlacklist, description: L10n.descBlacklist,
                  hint: "example.com",
                  keywords: ["blacklist", "黑名单", "domain"]),

            // 通知中心
            .init("dndEnabled", .notifications,
                  title: L10n.notifDND, description: L10n.descDnd,
                  keywords: ["dnd", "mute", "静音", "免打扰"]),
            .init("dndTimeRange", .notifications,
                  title: L10n.notifDNDTime, description: L10n.descDndTime,
                  keywords: ["time", "时段", "时间"]),

            // 天气
            .init("weatherAPIHost", .weather,
                  title: L10n.weatherAPIHost, description: L10n.descWeatherAPIHost,
                  hint: "devapi.qweather.com",
                  keywords: ["host", "api", "url", "天气"]),
            .init("weatherAPIKey", .weather,
                  title: L10n.weatherAPIKey, description: L10n.descWeatherAPIKey,
                  hint: "X-QW-Api-Key",
                  keywords: ["api", "key", "token", "和风", "天气"]),
            .init("weatherManualCity", .weather,
                  title: L10n.weatherCity, description: L10n.descWeatherCity,
                  hint: L10n.weatherAuto,
                  keywords: ["city", "城市", "定位"]),
            .init("weatherManualLocationID", .weather,
                  title: L10n.weatherLocationID, description: L10n.descWeatherLocationID,
                  hint: "101010100",
                  keywords: ["location", "id", "和风"]),

            // 社区
            .init("communityUploadUsername", .community,
                  title: L10n.settingsUsername, description: L10n.descUsername,
                  hint: L10n.settingsUsername,
                  keywords: ["username", "用户名", "上传"]),

        // 快捷键
        .init("hotkeyBindings", .shortcuts,
              title: L10n.shortcutTitle, description: L10n.descHotkeyBindings,
              keywords: ["hotkey", "shortcut", "热键"]),

            // 语音操作
            .init("voiceControl", .voice,
                  title: L10n.voiceEnableControl, description: L10n.voiceEnableControlDesc,
                  keywords: ["语音控制", "voice", "control", "指令"]),
            .init("voiceSpeech", .voice,
                  title: L10n.voiceEnableSpeech, description: L10n.voiceEnableSpeechDesc,
                  keywords: ["语音播报", "speech", "播报", "tts"]),
            .init("voiceWakeWord", .voice,
                  title: L10n.voiceWakeWord, description: L10n.voiceWakeWordHint,
                  keywords: ["唤醒词", "wake", "word"]),
            .init("voiceTTS", .voice,
                  title: L10n.voiceTTSConfig, description: L10n.voiceTTSSpeed,
                  keywords: ["tts", "语音合成", "语速", "音调", "音量"]),
            .init("voiceSTT", .voice,
                  title: L10n.voiceSTTConfig, description: L10n.voiceSTTLanguage,
                  keywords: ["stt", "语音识别", "识别语言"]),

            // AI 助手
            .init("aiProvider", .ai,
                  title: "服务商", description: "选择 AI 服务商或自定义地址",
                  keywords: ["provider", "服务商", "preset", "预设", "openai", "deepseek", "mimo"]),
            .init("aiServer", .ai,
                  title: L10n.aiServer, description: L10n.aiLocal,
                  hint: "http://localhost:11434",
                  keywords: ["server", "url", "服务", "地址", "ollama"]),
            .init("aiApiKey", .ai,
                  title: L10n.aiApiKey, description: L10n.aiProtocol,
                  keywords: ["api", "key", "token", "密钥"]),
            .init("aiModelName", .ai,
                  title: L10n.aiModelName, description: L10n.aiModels,
                  keywords: ["model", "模型", "llama", "gpt"]),
            .init("aiTTS", .ai,
                  title: L10n.voiceTTSConfig, description: L10n.voiceTTSSpeed,
                  keywords: ["tts", "语音合成", "语速", "音调", "音量"]),
            .init("aiSTT", .ai,
                  title: L10n.voiceSTTConfig, description: L10n.voiceSTTLanguage,
                  keywords: ["stt", "语音识别", "识别语言"]),
        ]
    }
}
