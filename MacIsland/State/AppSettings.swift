//
//  AppSettings.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI
import Combine

// MARK: - Appearance Mode

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"
    var id: String { rawValue }
    var displayName: String {
        switch self { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" }
    }
    var systemImage: String {
        switch self { case .system: return "circle.lefthalf.filled"; case .light: return "sun.max"; case .dark: return "moon" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

// MARK: - Accent Color Option

enum AccentColorOption: String, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green, teal, indigo
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .blue: return "蓝色"; case .purple: return "紫色"; case .pink: return "粉色"
        case .red: return "红色"; case .orange: return "橙色"; case .yellow: return "黄色"
        case .green: return "绿色"; case .teal: return "青色"; case .indigo: return "靛蓝"
        }
    }
    var color: Color {
        switch self {
        case .blue: return .blue; case .purple: return .purple; case .pink: return .pink
        case .red: return .red; case .orange: return .orange; case .yellow: return .yellow
        case .green: return .green; case .teal: return .teal; case .indigo: return .indigo
        }
    }
}

// MARK: - App Settings

/// 全局共享设置 — UserDefaults 持久化，灵动岛与设置窗口共用同一数据源
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var animationSpeed: AnimationSpeed {
        didSet { defaults.set(animationSpeed.rawValue, forKey: Keys.animationSpeed) }
    }
    @Published var springAnimation: Bool {
        didSet { defaults.set(springAnimation, forKey: Keys.springAnimation) }
    }
    @Published var clipboardEnabled: Bool {
        didSet { defaults.set(clipboardEnabled, forKey: Keys.clipboardEnabled) }
    }
    /// 自定义快捷键绑定（HotkeyAction → KeyCombo），UserDefaults JSON 持久化
    @Published var hotkeyBindings: [HotkeyAction: KeyCombo] {
        didSet { Self.saveHotkeyBindings(hotkeyBindings, defaults: defaults) }
    }

    // MARK: - 番茄钟配置

    /// 专注时长（分钟）
    @Published var pomodoroWorkMinutes: Int {
        didSet { defaults.set(pomodoroWorkMinutes, forKey: Keys.pomodoroWorkMinutes) }
    }
    /// 短休时长（分钟）
    @Published var pomodoroShortBreakMinutes: Int {
        didSet { defaults.set(pomodoroShortBreakMinutes, forKey: Keys.pomodoroShortBreakMinutes) }
    }
    /// 长休时长（分钟）
    @Published var pomodoroLongBreakMinutes: Int {
        didSet { defaults.set(pomodoroLongBreakMinutes, forKey: Keys.pomodoroLongBreakMinutes) }
    }
    /// 长休间隔（每完成 N 个番茄后进入长休）
    @Published var pomodoroLongBreakInterval: Int {
        didSet { defaults.set(pomodoroLongBreakInterval, forKey: Keys.pomodoroLongBreakInterval) }
    }

    // MARK: - 剪贴板配置

    /// URL 检测模式
    @Published var clipboardUrlDetectMode: ClipboardUrlDetectMode {
        didSet { defaults.set(clipboardUrlDetectMode.rawValue, forKey: Keys.clipboardUrlDetectMode) }
    }
    /// 域名黑名单
    @Published var blacklistedDomains: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(Array(blacklistedDomains)) {
                defaults.set(data, forKey: Keys.blacklistedDomains)
            }
        }
    }

    // MARK: - 外观

    /// 外观模式（深色/浅色/跟随系统）
    @Published var appearanceMode: AppAppearance {
        didSet { defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }
    /// 强调色
    @Published var accentColorOption: AccentColorOption {
        didSet { defaults.set(accentColorOption.rawValue, forKey: Keys.accentColorOption) }
    }
    /// 灵动岛透明度 (0.0 ~ 1.0)
    @Published var islandOpacity: Double {
        didSet { defaults.set(islandOpacity, forKey: Keys.islandOpacity) }
    }
    /// 壁纸透明度 (0.0 ~ 1.0)，独立于灵动岛整体透明度
    @Published var wallpaperOpacity: Double {
        didSet { defaults.set(wallpaperOpacity, forKey: Keys.wallpaperOpacity) }
    }
    /// 开机自启动
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // MARK: - 久坐提醒

    /// 久坐提醒是否启用
    @Published var breakReminderEnabled: Bool {
        didSet { defaults.set(breakReminderEnabled, forKey: Keys.breakReminderEnabled) }
    }
    /// 久坐提醒间隔（分钟）
    @Published var breakReminderMinutes: Int {
        didSet { defaults.set(breakReminderMinutes, forKey: Keys.breakReminderMinutes) }
    }

    // MARK: - 歌词

    /// 歌词源偏好（netease/qqmusic/kugou/lrclib/auto）
    @Published var preferredLyricsSource: String {
        didSet { defaults.set(preferredLyricsSource, forKey: Keys.preferredLyricsSource) }
    }

    // MARK: - 天气

    /// 手动城市名（空=自动定位）
    @Published var weatherManualCity: String {
        didSet { defaults.set(weatherManualCity, forKey: Keys.weatherManualCity) }
    }
    /// 手动 locationID
    @Published var weatherManualLocationID: String {
        didSet { defaults.set(weatherManualLocationID, forKey: Keys.weatherManualLocationID) }
    }

    // MARK: - 壁纸存储

    /// 自定义壁纸存储路径（空=使用默认 Application Support 路径）
    @Published var customWallpaperPath: String {
        didSet { defaults.set(customWallpaperPath, forKey: Keys.customWallpaperPath) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let appearanceMode = "appearanceMode"
        static let accentColorOption = "accentColorOption"
        static let animationSpeed = "animationSpeed"
        static let springAnimation = "springAnimation"
        static let clipboardEnabled = "clipboardEnabled"
        static let hotkeyBindings = "hotkeyBindings"
        static let pomodoroWorkMinutes = "pomodoroWorkMinutes"
        static let pomodoroShortBreakMinutes = "pomodoroShortBreakMinutes"
        static let pomodoroLongBreakMinutes = "pomodoroLongBreakMinutes"
        static let pomodoroLongBreakInterval = "pomodoroLongBreakInterval"
        static let clipboardUrlDetectMode = "clipboardUrlDetectMode"
        static let blacklistedDomains = "blacklistedDomains"
        static let islandOpacity = "islandOpacity"
        static let wallpaperOpacity = "wallpaperOpacity"
        static let launchAtLogin = "launchAtLogin"
        static let breakReminderEnabled = "breakReminderEnabled"
        static let breakReminderMinutes = "breakReminderMinutes"
        static let preferredLyricsSource = "preferredLyricsSource"
        static let weatherManualCity = "weatherManualCity"
        static let weatherManualLocationID = "weatherManualLocationID"
        static let customWallpaperPath = "customWallpaperPath"
    }

    private init() {
        appearanceMode = (defaults.string(forKey: Keys.appearanceMode))
            .flatMap(AppAppearance.init) ?? .dark
        accentColorOption = (defaults.string(forKey: Keys.accentColorOption))
            .flatMap(AccentColorOption.init) ?? .blue
        animationSpeed = (defaults.string(forKey: Keys.animationSpeed))
            .flatMap(AnimationSpeed.init) ?? .medium
        springAnimation = defaults.object(forKey: Keys.springAnimation) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Keys.clipboardEnabled) as? Bool ?? true
        hotkeyBindings = Self.loadHotkeyBindings(defaults: defaults)
        pomodoroWorkMinutes = defaults.object(forKey: Keys.pomodoroWorkMinutes) as? Int ?? 25
        pomodoroShortBreakMinutes = defaults.object(forKey: Keys.pomodoroShortBreakMinutes) as? Int ?? 5
        pomodoroLongBreakMinutes = defaults.object(forKey: Keys.pomodoroLongBreakMinutes) as? Int ?? 15
        pomodoroLongBreakInterval = defaults.object(forKey: Keys.pomodoroLongBreakInterval) as? Int ?? 4

        // 剪贴板配置
        clipboardUrlDetectMode = (defaults.string(forKey: Keys.clipboardUrlDetectMode))
            .flatMap(ClipboardUrlDetectMode.init) ?? .httpHttps
        if let data = defaults.data(forKey: Keys.blacklistedDomains),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            blacklistedDomains = Set(decoded)
        } else {
            blacklistedDomains = []
        }

        // 外观
        islandOpacity = defaults.object(forKey: Keys.islandOpacity) as? Double ?? 1.0
        wallpaperOpacity = defaults.object(forKey: Keys.wallpaperOpacity) as? Double ?? 1.0
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false

        // 久坐提醒
        breakReminderEnabled = defaults.object(forKey: Keys.breakReminderEnabled) as? Bool ?? false
        breakReminderMinutes = defaults.object(forKey: Keys.breakReminderMinutes) as? Int ?? 60

        // 歌词
        preferredLyricsSource = defaults.string(forKey: Keys.preferredLyricsSource) ?? "auto"

        // 天气
        weatherManualCity = defaults.string(forKey: Keys.weatherManualCity) ?? ""
        weatherManualLocationID = defaults.string(forKey: Keys.weatherManualLocationID) ?? ""

        // 壁纸存储
        customWallpaperPath = defaults.string(forKey: Keys.customWallpaperPath) ?? ""
    }

    // MARK: - Hotkey Bindings Persistence

    private static func loadHotkeyBindings(defaults: UserDefaults) -> [HotkeyAction: KeyCombo] {
        guard let data = defaults.data(forKey: Keys.hotkeyBindings),
              let decoded = try? JSONDecoder().decode([HotkeyAction: KeyCombo].self, from: data)
        else {
            return KeyCombo.defaultBindings
        }
        // 补充缺失的新 action（升级兼容）
        var bindings = decoded
        for action in HotkeyAction.allCases where bindings[action] == nil {
            bindings[action] = KeyCombo.defaultBindings[action]
        }
        return bindings
    }

    private static func saveHotkeyBindings(_ bindings: [HotkeyAction: KeyCombo], defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: Keys.hotkeyBindings)
        }
    }

    /// 恢复所有快捷键为默认值
    func resetHotkeyBindings() {
        hotkeyBindings = KeyCombo.defaultBindings
    }
}
