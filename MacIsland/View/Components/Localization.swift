//
//  Localization.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Language

/// 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh"
    case en = "en"
    case ja = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

// MARK: - Localization Manager

/// 本地化管理器 — 语言变化时通知所有视图刷新
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        self.currentLanguage = AppLanguage(rawValue: raw) ?? .zh
    }

    /// 按 key 查翻译
    func localize(_ key: String) -> String {
        // 优先从 lproj bundle 取
        if let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        // 回退到内置字典
        switch currentLanguage {
        case .ja: return jaStrings[key] ?? zhStrings[key] ?? key
        case .en: return enStrings[key] ?? zhStrings[key] ?? key
        case .zh: return zhStrings[key] ?? key
        }
    }
}

// MARK: - L10n 便捷访问

/// 本地化字符串 — 调用 L10n.key 时自动从 LocalizationManager 读取
enum L10n {
    private static func t(_ key: String) -> String { LocalizationManager.shared.localize(key) }

    // MARK: - Tab
    static var tabTodo: String { t("tab_todo") }
    static var tabMemo: String { t("tab_memo") }
    static var tabEvent: String { t("tab_event") }
    static var tabAlarm: String { t("tab_alarm") }
    static var tabBookmark: String { t("tab_bookmark") }
    static var tabAI: String { t("tab_ai") }
    static var tabSettings: String { t("tab_settings") }
    static var tabToolbox: String { t("tab_toolbox") }
    static var tabNotifications: String { t("tab_notifications") }
    static var tabWallpaper: String { t("tab_wallpaper") }

    // MARK: - Common
    static var add: String { t("common_add") }
    static var delete: String { t("common_delete") }
    static var save: String { t("common_save") }
    static var cancel: String { t("common_cancel") }
    static var confirm: String { t("common_confirm") }
    static var close: String { t("common_close") }
    static var open: String { t("common_open") }
    static var reset: String { t("common_reset") }
    static var copy: String { t("common_copy") }
    static var search: String { t("common_search") }
    static var noData: String { t("common_no_data") }
    static var done: String { t("common_done") }
    static var edit: String { t("common_edit") }
    static var clear: String { t("common_clear") }
    static var restore: String { t("common_restore") }
    static var enabled: String { t("common_enabled") }
    static var disabled: String { t("common_disabled") }
    static var on: String { t("common_on") }
    static var off: String { t("common_off") }
    static var yes: String { t("common_yes") }
    static var no: String { t("common_no") }
    static var ok: String { t("common_ok") }
    static var error: String { t("common_error") }
    static var loading: String { t("common_loading") }
    static var empty: String { t("common_empty") }
    static var count: String { t("common_count") }
    static var version: String { t("common_version") }

    // MARK: - Todo
    static var todoTitle: String { t("todo_title") }
    static var todoPlaceholder: String { t("todo_placeholder") }
    static var todoSubtask: String { t("todo_subtask") }
    static var todoDescription: String { t("todo_description") }
    static var todoTrash: String { t("todo_trash") }
    static var todoEmpty: String { t("todo_empty") }
    static var todoComplete: String { t("todo_complete") }
    static var todoPending: String { t("todo_pending") }
    static var todoPriority: String { t("todo_priority") }
    static var todoHigh: String { t("todo_high") }
    static var todoMedium: String { t("todo_medium") }
    static var todoLow: String { t("todo_low") }

    // MARK: - Memo
    static var memoTitle: String { t("memo_title") }
    static var memoPlaceholder: String { t("memo_placeholder") }
    static var memoEmpty: String { t("memo_empty") }

    // MARK: - Event
    static var eventTitle: String { t("event_title") }
    static var eventCountdown: String { t("event_countdown") }
    static var eventAnniversary: String { t("event_anniversary") }
    static var eventBirthday: String { t("event_birthday") }
    static var eventHoliday: String { t("event_holiday") }
    static var eventExam: String { t("event_exam") }
    static var eventName: String { t("event_name") }
    static var eventDate: String { t("event_date") }
    static var eventDaysLeft: String { t("event_days_left") }
    static var eventDaysPassed: String { t("event_days_passed") }

    // MARK: - Alarm
    static var alarmTitle: String { t("alarm_title") }
    static var alarmLabel: String { t("alarm_label") }
    static var alarmRepeat: String { t("alarm_repeat") }
    static var alarmOnce: String { t("alarm_once") }
    static var alarmRingtone: String { t("alarm_ringtone") }

    // MARK: - Bookmark
    static var bookmarkTitle: String { t("bookmark_title") }
    static var bookmarkName: String { t("bookmark_name") }
    static var bookmarkURL: String { t("bookmark_url") }
    static var bookmarkEmpty: String { t("bookmark_empty") }

    // MARK: - Toolbox
    static var toolboxTitle: String { t("toolbox_title") }
    static var toolboxFileSearch: String { t("toolbox_file_search") }
    static var toolboxClipboard: String { t("toolbox_clipboard") }
    static var toolboxFileHash: String { t("toolbox_file_hash") }
    static var toolboxEncoding: String { t("toolbox_encoding") }
    static var toolboxTranslate: String { t("toolbox_translate") }
    static var toolboxMokugyo: String { t("toolbox_mokugyo") }
    static var toolboxBreakReminder: String { t("toolbox_break_reminder") }

    // MARK: - File Search
    static var fileSearchPlaceholder: String { t("file_search_placeholder") }
    static var fileSearchDepth: String { t("file_search_depth") }
    static var fileSearchExt: String { t("file_search_ext") }
    static var fileSearchResults: String { t("file_search_results") }
    static var fileSearchEmpty: String { t("file_search_empty") }

    // MARK: - Clipboard
    static var clipboardHistory: String { t("clipboard_history") }
    static var clipboardRecords: String { t("clipboard_records") }
    static var clipboardEmpty: String { t("clipboard_empty") }
    static var clipboardCopied: String { t("clipboard_copied") }

    // MARK: - File Hash
    static var fileHashTitle: String { t("file_hash_title") }
    static var fileHashSelect: String { t("file_hash_select") }
    static var fileHashComputing: String { t("file_hash_computing") }
    static var fileHashClickCopy: String { t("file_hash_click_copy") }

    // MARK: - Encoding
    static var encodingTitle: String { t("encoding_title") }
    static var encodingFrom: String { t("encoding_from") }
    static var encodingTo: String { t("encoding_to") }
    static var encodingConvert: String { t("encoding_convert") }
    static var encodingResult: String { t("encoding_result") }

    // MARK: - Translate
    static var translateTitle: String { t("translate_title") }
    static var translateFrom: String { t("translate_from") }
    static var translateTo: String { t("translate_to") }
    static var translateButton: String { t("translate_button") }
    static var translateResult: String { t("translate_result") }
    static var translateAuto: String { t("translate_auto") }

    // MARK: - Mokugyo
    static var mokugyoTitle: String { t("mokugyo_title") }
    static var mokugyoSubtitle: String { t("mokugyo_subtitle") }
    static var mokugyoTaps: String { t("mokugyo_taps") }
    static var mokugyoReset: String { t("mokugyo_reset") }
    static var mokugyoCopyCount: String { t("mokugyo_copy_count") }

    // MARK: - Break Reminder
    static var breakTitle: String { t("break_title") }
    static var breakSeated: String { t("break_seated") }
    static var breakInterval: String { t("break_interval") }
    static var breakEnable: String { t("break_enable") }
    static var breakReset: String { t("break_reset") }
    static var breakMinutes: String { t("break_minutes") }

    // MARK: - Notification Center
    static var notifCenter: String { t("notif_center") }
    static var notifCount: String { t("notif_count") }
    static var notifClear: String { t("notif_clear") }
    static var notifClearConfirm: String { t("notif_clear_confirm") }
    static var notifEmpty: String { t("notif_empty") }
    static var notifAll: String { t("notif_all") }
    static var notifDND: String { t("notif_dnd") }
    static var notifDNDTime: String { t("notif_dnd_time") }
    static var notifDNDActive: String { t("notif_dnd_active") }
    static var notifFrom: String { t("notif_from") }

    // MARK: - Music
    static var musicNowPlaying: String { t("music_now_playing") }
    static var musicNoPlayback: String { t("music_no_playback") }
    static var musicLyrics: String { t("music_lyrics") }
    static var musicSource: String { t("music_source") }

    // MARK: - Weather
    static var weatherTitle: String { t("weather_title") }
    static var weatherWind: String { t("weather_wind") }
    static var weatherHumidity: String { t("weather_humidity") }
    static var weatherAuto: String { t("weather_auto") }
    static var weatherCity: String { t("weather_city") }
    static var weatherLocationID: String { t("weather_location_id") }
    static var weatherClear: String { t("weather_clear") }

    // MARK: - Wallpaper
    static var wallpaperTitle: String { t("wallpaper_title") }
    static var wallpaperLocal: String { t("wallpaper_local") }
    static var wallpaperCurrent: String { t("wallpaper_current") }
    static var wallpaperInUse: String { t("wallpaper_in_use") }
    static var wallpaperDetail: String { t("wallpaper_detail") }
    static var wallpaperAdd: String { t("wallpaper_add") }
    static var wallpaperUpload: String { t("wallpaper_upload") }
    static var wallpaperUploadConfirm: String { t("wallpaper_upload_confirm") }
    static var wallpaperDeleteConfirm: String { t("wallpaper_delete_confirm") }
    static var wallpaperSelect: String { t("wallpaper_select") }
    static var wallpaperFormats: String { t("wallpaper_formats") }
    static var wallpaperPath: String { t("wallpaper_path") }
    static var wallpaperPathDefault: String { t("wallpaper_path_default") }

    // MARK: - AI
    static var aiTitle: String { t("ai_title") }
    static var aiConfig: String { t("ai_config") }
    static var aiApiKey: String { t("ai_api_key") }
    static var aiServer: String { t("ai_server") }
    static var aiModels: String { t("ai_models") }
    static var aiLocal: String { t("ai_local") }
    static var aiSend: String { t("ai_send") }
    static var aiPlaceholder: String { t("ai_placeholder") }

    // MARK: - Settings
    static var settingsGeneral: String { t("settings_general") }
    static var settingsShortcuts: String { t("settings_shortcuts") }
    static var settingsAbout: String { t("settings_about") }
    static var settingsAutostart: String { t("settings_autostart") }
    static var settingsOpacity: String { t("settings_opacity") }
    static var settingsWallpaperOpacity: String { t("settings_wallpaper_opacity") }
    static var settingsAnimation: String { t("settings_animation") }
    static var settingsClipboard: String { t("settings_clipboard") }
    static var settingsAppearance: String { t("settings_appearance") }
    static var settingsAccentColor: String { t("settings_accent_color") }
    static var settingsLanguage: String { t("settings_language") }
    static var settingsTheme: String { t("settings_theme") }
    static var settingsThemeDark: String { t("settings_theme_dark") }
    static var settingsThemeLight: String { t("settings_theme_light") }
    static var settingsThemeSystem: String { t("settings_theme_system") }
    static var settingsBlacklist: String { t("settings_blacklist") }
    static var settingsBlacklistEmpty: String { t("settings_blacklist_empty") }
    static var settingsLyricsSource: String { t("settings_lyrics_source") }
    static var settingsCommunity: String { t("settings_community") }
    static var settingsUsername: String { t("settings_username") }
    static var settingsSpring: String { t("settings_spring") }
    static var settingsSpeed: String { t("settings_speed") }
    static var settingsSpeedSlow: String { t("settings_speed_slow") }
    static var settingsSpeedMedium: String { t("settings_speed_medium") }
    static var settingsSpeedFast: String { t("settings_speed_fast") }
    static var settingsUrlMode: String { t("settings_url_mode") }
    static var settingsHttpsOnly: String { t("settings_https_only") }
    static var settingsHttpHttps: String { t("settings_http_https") }
    static var settingsDomainOnly: String { t("settings_domain_only") }
    static var settingsLinkDetect: String { t("settings_link_detect") }

    // MARK: - Shortcuts
    static var shortcutTitle: String { t("shortcut_title") }
    static var shortcutPermission: String { t("shortcut_permission") }
    static var shortcutPermissionDenied: String { t("shortcut_permission_denied") }
    static var shortcutPermissionGranted: String { t("shortcut_permission_granted") }
    static var shortcutOpenSettings: String { t("shortcut_open_settings") }
    static var shortcutPressKey: String { t("shortcut_press_key") }
    static var shortcutConflict: String { t("shortcut_conflict") }
    static var shortcutConflictMsg: String { t("shortcut_conflict_msg") }
    static var shortcutSwap: String { t("shortcut_swap") }
    static var shortcutReset: String { t("shortcut_reset") }

    // MARK: - About
    static var aboutTitle: String { t("about_title") }
    static var aboutSubtitle: String { t("about_subtitle") }

    // MARK: - Timer
    static var timerTitle: String { t("timer_title") }
    static var timerPomodoro: String { t("timer_pomodoro") }
    static var timerCountdown: String { t("timer_countdown") }
    static var timerWork: String { t("timer_work") }
    static var timerBreak: String { t("timer_break") }
    static var timerLongBreak: String { t("timer_long_break") }
    static var timerStart: String { t("timer_start") }
    static var timerPause: String { t("timer_pause") }
    static var timerStop: String { t("timer_stop") }

    // MARK: - Monitor
    static var monitorTitle: String { t("monitor_title") }
    static var monitorCPU: String { t("monitor_cpu") }
    static var monitorMemory: String { t("monitor_memory") }
    static var monitorDisk: String { t("monitor_disk") }
    static var monitorBattery: String { t("monitor_battery") }
    static var monitorNetwork: String { t("monitor_network") }

    // MARK: - Island
    static var islandHide: String { t("island_hide") }
    static var islandShow: String { t("island_show") }
    static var islandCollapse: String { t("island_collapse") }
    static var islandExit: String { t("island_exit") }
    static var islandSettings: String { t("island_settings") }
    static var islandPreferences: String { t("island_preferences") }

    // MARK: - Misc
    static var today: String { t("today") }
    static var yesterday: String { t("yesterday") }
    static var minutes: String { t("minutes") }
    static var hours: String { t("hours") }
    static var days: String { t("days") }
}

// MARK: - Language Settings View

/// 语言设置视图 — 切换即时生效
struct LanguageSettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        Picker("语言", selection: $loc.currentLanguage) {
            ForEach(AppLanguage.allCases) { lang in
                Text(lang.displayName).tag(lang)
            }
        }
    }
}

// MARK: - 中文翻译

private let zhStrings: [String: String] = [
    // Tab
    "tab_todo": "待办", "tab_memo": "便签", "tab_event": "倒数日",
    "tab_alarm": "闹钟", "tab_bookmark": "书签", "tab_ai": "AI",
    "tab_settings": "设置", "tab_toolbox": "工具", "tab_notifications": "通知",
    "tab_wallpaper": "壁纸",
    // Common
    "common_add": "添加", "common_delete": "删除", "common_save": "保存",
    "common_cancel": "取消", "common_confirm": "确认", "common_close": "关闭",
    "common_open": "打开", "common_reset": "重置", "common_copy": "复制",
    "common_search": "搜索", "common_no_data": "暂无数据",
    "common_done": "完成", "common_edit": "编辑", "common_clear": "清空",
    "common_restore": "恢复默认", "common_enabled": "已启用", "common_disabled": "已禁用",
    "common_on": "开", "common_off": "关", "common_yes": "是", "common_no": "否",
    "common_ok": "好", "common_error": "错误", "common_loading": "加载中...",
    "common_empty": "暂无", "common_count": "个", "common_version": "版本",
    // Todo
    "todo_title": "待办事项", "todo_placeholder": "添加待办...",
    "todo_subtask": "子任务", "todo_description": "描述",
    "todo_trash": "回收站", "todo_empty": "管理你的任务，支持优先级和子任务",
    "todo_complete": "完成", "todo_pending": "待办",
    "todo_priority": "优先级", "todo_high": "高", "todo_medium": "中", "todo_low": "低",
    // Memo
    "memo_title": "便签", "memo_placeholder": "标题", "memo_empty": "快速记录想法和笔记",
    // Event
    "event_title": "倒计时 & 纪念日", "event_countdown": "倒计时",
    "event_anniversary": "纪念日", "event_birthday": "生日",
    "event_holiday": "节日", "event_exam": "考试",
    "event_name": "事件名称", "event_date": "日期",
    "event_days_left": "天后", "event_days_passed": "天前",
    // Alarm
    "alarm_title": "闹钟", "alarm_label": "闹钟名称", "alarm_repeat": "重复",
    "alarm_once": "单次", "alarm_ringtone": "铃声",
    // Bookmark
    "bookmark_title": "URL 书签", "bookmark_name": "名称",
    "bookmark_url": "链接地址", "bookmark_empty": "收藏常用链接，快速访问",
    // Toolbox
    "toolbox_title": "工具箱", "toolbox_file_search": "文件搜索", "toolbox_clipboard": "剪贴板",
    "toolbox_file_hash": "文件哈希", "toolbox_encoding": "编码转换",
    "toolbox_translate": "翻译", "toolbox_mokugyo": "木鱼", "toolbox_break_reminder": "久坐提醒",
    // File Search
    "file_search_placeholder": "搜索文件名...", "file_search_depth": "深度",
    "file_search_ext": "扩展名", "file_search_results": "个结果",
    "file_search_empty": "输入文件名开始搜索",
    // Clipboard
    "clipboard_history": "剪贴板历史", "clipboard_records": "条记录",
    "clipboard_empty": "复制文本后自动记录", "clipboard_copied": "已复制",
    // File Hash
    "file_hash_title": "文件哈希校验", "file_hash_select": "拖拽文件或点击选择...",
    "file_hash_computing": "计算中...", "file_hash_click_copy": "点击复制",
    // Encoding
    "encoding_title": "编码转换", "encoding_from": "从", "encoding_to": "到",
    "encoding_convert": "转换", "encoding_result": "结果",
    // Translate
    "translate_title": "翻译", "translate_from": "从", "translate_to": "到",
    "translate_button": "翻译", "translate_result": "翻译结果", "translate_auto": "自动",
    // Mokugyo
    "mokugyo_title": "木鱼冥想", "mokugyo_subtitle": "静心敲击，放松身心",
    "mokugyo_taps": "次敲击", "mokugyo_reset": "重置", "mokugyo_copy_count": "复制计数",
    // Break Reminder
    "break_title": "久坐提醒", "break_seated": "已坐",
    "break_interval": "提醒间隔", "break_enable": "启用提醒",
    "break_reset": "我知道了，重置计时", "break_minutes": "分钟",
    // Notification Center
    "notif_center": "通知中心", "notif_count": "条通知", "notif_clear": "清空",
    "notif_clear_confirm": "确定要清空所有通知记录吗？", "notif_empty": "暂无通知",
    "notif_all": "全部", "notif_dnd": "免打扰", "notif_dnd_time": "时段",
    "notif_dnd_active": "生效中", "notif_from": "来源",
    // Music
    "music_now_playing": "正在播放", "music_no_playback": "暂无播放",
    "music_lyrics": "歌词", "music_source": "歌词源",
    // Weather
    "weather_title": "天气", "weather_wind": "风速", "weather_humidity": "湿度",
    "weather_auto": "自动定位", "weather_city": "手动城市", "weather_location_id": "Location ID",
    "weather_clear": "清除手动设置",
    // Wallpaper
    "wallpaper_title": "壁纸", "wallpaper_local": "本地壁纸", "wallpaper_current": "当前壁纸",
    "wallpaper_in_use": "使用中", "wallpaper_detail": "壁纸详情",
    "wallpaper_add": "点击 + 添加本地壁纸", "wallpaper_upload": "上传",
    "wallpaper_upload_confirm": "上传到社区壁纸仓库，需经审核后展示",
    "wallpaper_delete_confirm": "确定要删除吗？", "wallpaper_select": "选择壁纸",
    "wallpaper_formats": "支持 JPG / PNG / WebP / MP4 / MOV",
    "wallpaper_path": "存储路径", "wallpaper_path_default": "默认：Application Support/MacIsland/Wallpapers",
    // AI
    "ai_title": "AI 助手", "ai_config": "AI 服务配置", "ai_api_key": "API Key（本地服务可留空）",
    "ai_server": "服务地址", "ai_models": "个可用模型", "ai_local": "本地: Ollama / llama.cpp / LM Studio / vLLM",
    "ai_send": "发送", "ai_placeholder": "输入消息...",
    // Settings
    "settings_general": "通用", "settings_shortcuts": "快捷键", "settings_about": "关于",
    "settings_autostart": "开机自启动", "settings_opacity": "灵动岛透明度",
    "settings_wallpaper_opacity": "壁纸透明度", "settings_animation": "动画",
    "settings_clipboard": "剪贴板", "settings_appearance": "外观",
    "settings_accent_color": "强调色", "settings_language": "语言",
    "settings_theme": "外观模式", "settings_theme_dark": "深色", "settings_theme_light": "浅色",
    "settings_theme_system": "跟随系统", "settings_blacklist": "域名黑名单",
    "settings_blacklist_empty": "暂无黑名单域名", "settings_lyrics_source": "歌词源",
    "settings_community": "社区", "settings_username": "上传用户名",
    "settings_spring": "弹簧动画", "settings_speed": "动画速度",
    "settings_speed_slow": "慢速", "settings_speed_medium": "中速", "settings_speed_fast": "快速",
    "settings_url_mode": "URL 检测模式", "settings_https_only": "仅 HTTPS",
    "settings_http_https": "HTTP + HTTPS", "settings_domain_only": "仅域名",
    "settings_link_detect": "链接检测",
    // Shortcuts
    "shortcut_title": "全局快捷键", "shortcut_permission": "辅助功能权限",
    "shortcut_permission_denied": "辅助功能权限未授予，快捷键不可用",
    "shortcut_permission_granted": "辅助功能权限已授予，快捷键可用",
    "shortcut_open_settings": "打开系统设置", "shortcut_press_key": "按下快捷键...",
    "shortcut_conflict": "快捷键冲突", "shortcut_conflict_msg": "已被使用",
    "shortcut_swap": "交换", "shortcut_reset": "恢复默认快捷键",
    // About
    "about_title": "MacIsland", "about_subtitle": "macOS 灵动岛桌面助手",
    // Timer
    "timer_title": "计时器", "timer_pomodoro": "番茄钟", "timer_countdown": "倒计时",
    "timer_work": "专注", "timer_break": "短休", "timer_long_break": "长休",
    "timer_start": "开始", "timer_pause": "暂停", "timer_stop": "停止",
    // Monitor
    "monitor_title": "系统监控", "monitor_cpu": "CPU", "monitor_memory": "内存",
    "monitor_disk": "磁盘", "monitor_battery": "电池", "monitor_network": "网络",
    // Island
    "island_hide": "隐藏灵动岛", "island_show": "显示灵动岛", "island_collapse": "折叠岛",
    "island_exit": "退出 MacIsland", "island_settings": "设置", "island_preferences": "偏好设置...",
    // Misc
    "today": "今天", "yesterday": "昨天", "minutes": "分钟", "hours": "小时", "days": "天",
]

// MARK: - 英文翻译

private let enStrings: [String: String] = [
    // Tab
    "tab_todo": "Todo", "tab_memo": "Memo", "tab_event": "Events",
    "tab_alarm": "Alarm", "tab_bookmark": "Bookmarks", "tab_ai": "AI",
    "tab_settings": "Settings", "tab_toolbox": "Tools", "tab_notifications": "Notifications",
    "tab_wallpaper": "Wallpaper",
    // Common
    "common_add": "Add", "common_delete": "Delete", "common_save": "Save",
    "common_cancel": "Cancel", "common_confirm": "Confirm", "common_close": "Close",
    "common_open": "Open", "common_reset": "Reset", "common_copy": "Copy",
    "common_search": "Search", "common_no_data": "No data",
    "common_done": "Done", "common_edit": "Edit", "common_clear": "Clear",
    "common_restore": "Restore Default", "common_enabled": "Enabled", "common_disabled": "Disabled",
    "common_on": "On", "common_off": "Off", "common_yes": "Yes", "common_no": "No",
    "common_ok": "OK", "common_error": "Error", "common_loading": "Loading...",
    "common_empty": "Empty", "common_count": "", "common_version": "Version",
    // Todo
    "todo_title": "Todo", "todo_placeholder": "Add todo...",
    "todo_subtask": "Subtask", "todo_description": "Description",
    "todo_trash": "Trash", "todo_empty": "Manage your tasks with priorities and subtasks",
    "todo_complete": "Done", "todo_pending": "Pending",
    "todo_priority": "Priority", "todo_high": "High", "todo_medium": "Medium", "todo_low": "Low",
    // Memo
    "memo_title": "Memo", "memo_placeholder": "Title", "memo_empty": "Quick notes and ideas",
    // Event
    "event_title": "Countdown & Anniversary", "event_countdown": "Countdown",
    "event_anniversary": "Anniversary", "event_birthday": "Birthday",
    "event_holiday": "Holiday", "event_exam": "Exam",
    "event_name": "Event Name", "event_date": "Date",
    "event_days_left": "days left", "event_days_passed": "days ago",
    // Alarm
    "alarm_title": "Alarm", "alarm_label": "Label", "alarm_repeat": "Repeat",
    "alarm_once": "Once", "alarm_ringtone": "Ringtone",
    // Bookmark
    "bookmark_title": "URL Bookmarks", "bookmark_name": "Name",
    "bookmark_url": "URL", "bookmark_empty": "Save your favorite links",
    // Toolbox
    "toolbox_title": "Toolbox", "toolbox_file_search": "File Search", "toolbox_clipboard": "Clipboard",
    "toolbox_file_hash": "File Hash", "toolbox_encoding": "Encoding",
    "toolbox_translate": "Translate", "toolbox_mokugyo": "Mokugyo", "toolbox_break_reminder": "Break Reminder",
    // File Search
    "file_search_placeholder": "Search filename...", "file_search_depth": "Depth",
    "file_search_ext": "Extension", "file_search_results": "results",
    "file_search_empty": "Enter filename to search",
    // Clipboard
    "clipboard_history": "Clipboard History", "clipboard_records": "records",
    "clipboard_empty": "Copied text will be recorded", "clipboard_copied": "Copied",
    // File Hash
    "file_hash_title": "File Hash", "file_hash_select": "Drag file or click to select...",
    "file_hash_computing": "Computing...", "file_hash_click_copy": "Click to copy",
    // Encoding
    "encoding_title": "Encoding", "encoding_from": "From", "encoding_to": "To",
    "encoding_convert": "Convert", "encoding_result": "Result",
    // Translate
    "translate_title": "Translate", "translate_from": "From", "translate_to": "To",
    "translate_button": "Translate", "translate_result": "Translation", "translate_auto": "Auto",
    // Mokugyo
    "mokugyo_title": "Mokugyo Meditation", "mokugyo_subtitle": "Tap to relax",
    "mokugyo_taps": "taps", "mokugyo_reset": "Reset", "mokugyo_copy_count": "Copy Count",
    // Break Reminder
    "break_title": "Break Reminder", "break_seated": "Seated",
    "break_interval": "Interval", "break_enable": "Enable Reminder",
    "break_reset": "OK, Reset Timer", "break_minutes": "min",
    // Notification Center
    "notif_center": "Notification Center", "notif_count": "notifications", "notif_clear": "Clear",
    "notif_clear_confirm": "Clear all notifications?", "notif_empty": "No notifications",
    "notif_all": "All", "notif_dnd": "Do Not Disturb", "notif_dnd_time": "Time Range",
    "notif_dnd_active": "Active", "notif_from": "Source",
    // Music
    "music_now_playing": "Now Playing", "music_no_playback": "No Playback",
    "music_lyrics": "Lyrics", "music_source": "Lyrics Source",
    // Weather
    "weather_title": "Weather", "weather_wind": "Wind", "weather_humidity": "Humidity",
    "weather_auto": "Auto Locate", "weather_city": "Manual City", "weather_location_id": "Location ID",
    "weather_clear": "Clear Manual Settings",
    // Wallpaper
    "wallpaper_title": "Wallpaper", "wallpaper_local": "Local Wallpaper", "wallpaper_current": "Current",
    "wallpaper_in_use": "In Use", "wallpaper_detail": "Wallpaper Detail",
    "wallpaper_add": "Click + to add wallpaper", "wallpaper_upload": "Upload",
    "wallpaper_upload_confirm": "Upload to community, pending review",
    "wallpaper_delete_confirm": "Delete this wallpaper?", "wallpaper_select": "Select Wallpaper",
    "wallpaper_formats": "Supports JPG / PNG / WebP / MP4 / MOV",
    "wallpaper_path": "Storage Path", "wallpaper_path_default": "Default: Application Support/MacIsland/Wallpapers",
    // AI
    "ai_title": "AI Assistant", "ai_config": "AI Service Config", "ai_api_key": "API Key (optional for local)",
    "ai_server": "Server", "ai_models": "models available", "ai_local": "Local: Ollama / llama.cpp / LM Studio / vLLM",
    "ai_send": "Send", "ai_placeholder": "Type a message...",
    // Settings
    "settings_general": "General", "settings_shortcuts": "Shortcuts", "settings_about": "About",
    "settings_autostart": "Launch at Login", "settings_opacity": "Island Opacity",
    "settings_wallpaper_opacity": "Wallpaper Opacity", "settings_animation": "Animation",
    "settings_clipboard": "Clipboard", "settings_appearance": "Appearance",
    "settings_accent_color": "Accent Color", "settings_language": "Language",
    "settings_theme": "Theme", "settings_theme_dark": "Dark", "settings_theme_light": "Light",
    "settings_theme_system": "System", "settings_blacklist": "Domain Blacklist",
    "settings_blacklist_empty": "No blacklisted domains", "settings_lyrics_source": "Lyrics Source",
    "settings_community": "Community", "settings_username": "Upload Username",
    "settings_spring": "Spring Animation", "settings_speed": "Animation Speed",
    "settings_speed_slow": "Slow", "settings_speed_medium": "Medium", "settings_speed_fast": "Fast",
    "settings_url_mode": "URL Detection", "settings_https_only": "HTTPS Only",
    "settings_http_https": "HTTP + HTTPS", "settings_domain_only": "Domain Only",
    "settings_link_detect": "Link Detection",
    // Shortcuts
    "shortcut_title": "Global Shortcuts", "shortcut_permission": "Accessibility",
    "shortcut_permission_denied": "Accessibility not granted, shortcuts unavailable",
    "shortcut_permission_granted": "Accessibility granted, shortcuts available",
    "shortcut_open_settings": "Open System Settings", "shortcut_press_key": "Press shortcut...",
    "shortcut_conflict": "Shortcut Conflict", "shortcut_conflict_msg": "is already used",
    "shortcut_swap": "Swap", "shortcut_reset": "Reset Shortcuts",
    // About
    "about_title": "MacIsland", "about_subtitle": "macOS Dynamic Island Desktop Assistant",
    // Timer
    "timer_title": "Timer", "timer_pomodoro": "Pomodoro", "timer_countdown": "Countdown",
    "timer_work": "Work", "timer_break": "Break", "timer_long_break": "Long Break",
    "timer_start": "Start", "timer_pause": "Pause", "timer_stop": "Stop",
    // Monitor
    "monitor_title": "System Monitor", "monitor_cpu": "CPU", "monitor_memory": "Memory",
    "monitor_disk": "Disk", "monitor_battery": "Battery", "monitor_network": "Network",
    // Island
    "island_hide": "Hide Island", "island_show": "Show Island", "island_collapse": "Collapse",
    "island_exit": "Quit MacIsland", "island_settings": "Settings", "island_preferences": "Preferences...",
    // Misc
    "today": "Today", "yesterday": "Yesterday", "minutes": "min", "hours": "hours", "days": "days",
]

// MARK: - 日文翻译

private let jaStrings: [String: String] = [
    // Tab
    "tab_todo": "やること", "tab_memo": "メモ", "tab_event": "イベント",
    "tab_alarm": "アラーム", "tab_bookmark": "ブックマーク", "tab_ai": "AI",
    "tab_settings": "設定", "tab_toolbox": "ツール", "tab_notifications": "通知",
    "tab_wallpaper": "壁紙",
    // Common
    "common_add": "追加", "common_delete": "削除", "common_save": "保存",
    "common_cancel": "キャンセル", "common_confirm": "確認", "common_close": "閉じる",
    "common_open": "開く", "common_reset": "リセット", "common_copy": "コピー",
    "common_search": "検索", "common_no_data": "データなし",
    "common_done": "完了", "common_edit": "編集", "common_clear": "クリア",
    "common_restore": "デフォルトに戻す", "common_enabled": "有効", "common_disabled": "無効",
    "common_on": "オン", "common_off": "オフ", "common_yes": "はい", "common_no": "いいえ",
    "common_ok": "OK", "common_error": "エラー", "common_loading": "読み込み中...",
    "common_empty": "なし", "common_count": "件", "common_version": "バージョン",
    // Todo
    "todo_title": "やることリスト", "todo_placeholder": "タスクを追加...",
    "todo_subtask": "サブタスク", "todo_description": "説明",
    "todo_trash": "ゴミ箱", "todo_empty": "優先度とサブタスクでタスクを管理",
    "todo_complete": "完了", "todo_pending": "未完了",
    "todo_priority": "優先度", "todo_high": "高", "todo_medium": "中", "todo_low": "低",
    // Memo
    "memo_title": "メモ", "memo_placeholder": "タイトル", "memo_empty": "メモやアイデアを素早く記録",
    // Event
    "event_title": "カウントダウン & 記念日", "event_countdown": "カウントダウン",
    "event_anniversary": "記念日", "event_birthday": "誕生日",
    "event_holiday": "祝日", "event_exam": "試験",
    "event_name": "イベント名", "event_date": "日付",
    "event_days_left": "日後", "event_days_passed": "日前",
    // Alarm
    "alarm_title": "アラーム", "alarm_label": "ラベル", "alarm_repeat": "繰り返し",
    "alarm_once": "1回", "alarm_ringtone": "着信音",
    // Bookmark
    "bookmark_title": "URL ブックマーク", "bookmark_name": "名前",
    "bookmark_url": "URL", "bookmark_empty": "お気に入りのリンクを保存",
    // Toolbox
    "toolbox_title": "ツールボックス", "toolbox_file_search": "ファイル検索", "toolbox_clipboard": "クリップボード",
    "toolbox_file_hash": "ファイルハッシュ", "toolbox_encoding": "エンコーディング",
    "toolbox_translate": "翻訳", "toolbox_mokugyo": "木魚", "toolbox_break_reminder": "休憩リマインダー",
    // File Search
    "file_search_placeholder": "ファイル名を検索...", "file_search_depth": "深度",
    "file_search_ext": "拡張子", "file_search_results": "件",
    "file_search_empty": "ファイル名を入力して検索",
    // Clipboard
    "clipboard_history": "クリップボード履歴", "clipboard_records": "件",
    "clipboard_empty": "コピーしたテキストが記録されます", "clipboard_copied": "コピー済み",
    // File Hash
    "file_hash_title": "ファイルハッシュ", "file_hash_select": "ドラッグまたはクリックで選択...",
    "file_hash_computing": "計算中...", "file_hash_click_copy": "クリックでコピー",
    // Encoding
    "encoding_title": "エンコーディング", "encoding_from": "から", "encoding_to": "へ",
    "encoding_convert": "変換", "encoding_result": "結果",
    // Translate
    "translate_title": "翻訳", "translate_from": "から", "translate_to": "へ",
    "translate_button": "翻訳", "translate_result": "翻訳結果", "translate_auto": "自動",
    // Mokugyo
    "mokugyo_title": "木魚瞑想", "mokugyo_subtitle": "叩いてリラックス",
    "mokugyo_taps": "回", "mokugyo_reset": "リセット", "mokugyo_copy_count": "カウントコピー",
    // Break Reminder
    "break_title": "休憩リマインダー", "break_seated": "着席",
    "break_interval": "間隔", "break_enable": "リマインダー有効",
    "break_reset": "了解、タイマーリセット", "break_minutes": "分",
    // Notification Center
    "notif_center": "通知センター", "notif_count": "件の通知", "notif_clear": "クリア",
    "notif_clear_confirm": "すべての通知を消去しますか？", "notif_empty": "通知なし",
    "notif_all": "すべて", "notif_dnd": "通知オフ", "notif_dnd_time": "時間帯",
    "notif_dnd_active": "有効中", "notif_from": "ソース",
    // Music
    "music_now_playing": "再生中", "music_no_playback": "再生なし",
    "music_lyrics": "歌詞", "music_source": "歌詞ソース",
    // Weather
    "weather_title": "天気", "weather_wind": "風速", "weather_humidity": "湿度",
    "weather_auto": "自動位置", "weather_city": "手動都市", "weather_location_id": "Location ID",
    "weather_clear": "手動設定をクリア",
    // Wallpaper
    "wallpaper_title": "壁紙", "wallpaper_local": "ローカル壁紙", "wallpaper_current": "現在の壁紙",
    "wallpaper_in_use": "使用中", "wallpaper_detail": "壁紙詳細",
    "wallpaper_add": "+ をクリックして壁紙を追加", "wallpaper_upload": "アップロード",
    "wallpaper_upload_confirm": "コミュニティにアップロード、審査後に表示",
    "wallpaper_delete_confirm": "この壁紙を削除しますか？", "wallpaper_select": "壁紙を選択",
    "wallpaper_formats": "JPG / PNG / WebP / MP4 / MOV 対応",
    "wallpaper_path": "保存パス", "wallpaper_path_default": "デフォルト：Application Support/MacIsland/Wallpapers",
    // AI
    "ai_title": "AI アシスタント", "ai_config": "AI サービス設定", "ai_api_key": "API Key（ローカルは任意）",
    "ai_server": "サーバー", "ai_models": "個のモデル", "ai_local": "ローカル：Ollama / llama.cpp / LM Studio / vLLM",
    "ai_send": "送信", "ai_placeholder": "メッセージを入力...",
    // Settings
    "settings_general": "一般", "settings_shortcuts": "ショートカット", "settings_about": "について",
    "settings_autostart": "ログイン時に起動", "settings_opacity": "アイランド透明度",
    "settings_wallpaper_opacity": "壁紙透明度", "settings_animation": "アニメーション",
    "settings_clipboard": "クリップボード", "settings_appearance": "外観",
    "settings_accent_color": "アクセントカラー", "settings_language": "言語",
    "settings_theme": "テーマ", "settings_theme_dark": "ダーク", "settings_theme_light": "ライト",
    "settings_theme_system": "システム", "settings_blacklist": "ドメインブラックリスト",
    "settings_blacklist_empty": "ブラックリストなし", "settings_lyrics_source": "歌詞ソース",
    "settings_community": "コミュニティ", "settings_username": "アップロードユーザー名",
    "settings_spring": "スプリングアニメーション", "settings_speed": "アニメーション速度",
    "settings_speed_slow": "遅い", "settings_speed_medium": "普通", "settings_speed_fast": "速い",
    "settings_url_mode": "URL 検出", "settings_https_only": "HTTPS のみ",
    "settings_http_https": "HTTP + HTTPS", "settings_domain_only": "ドメインのみ",
    "settings_link_detect": "リンク検出",
    // Shortcuts
    "shortcut_title": "グローバルショートカット", "shortcut_permission": "アクセシビリティ",
    "shortcut_permission_denied": "アクセシビリティ未許可、ショートカット不可",
    "shortcut_permission_granted": "アクセシビリティ許可済み",
    "shortcut_open_settings": "システム設定を開く", "shortcut_press_key": "ショートカットを押す...",
    "shortcut_conflict": "ショートカット競合", "shortcut_conflict_msg": "は既に使用されています",
    "shortcut_swap": "交換", "shortcut_reset": "ショートカットリセット",
    // About
    "about_title": "MacIsland", "about_subtitle": "macOS Dynamic Island デスクトップアシスタント",
    // Timer
    "timer_title": "タイマー", "timer_pomodoro": "ポモドーロ", "timer_countdown": "カウントダウン",
    "timer_work": "作業", "timer_break": "休憩", "timer_long_break": "長休憩",
    "timer_start": "開始", "timer_pause": "一時停止", "timer_stop": "停止",
    // Monitor
    "monitor_title": "システムモニター", "monitor_cpu": "CPU", "monitor_memory": "メモリ",
    "monitor_disk": "ディスク", "monitor_battery": "バッテリー", "monitor_network": "ネットワーク",
    // Island
    "island_hide": "アイランドを隠す", "island_show": "アイランドを表示", "island_collapse": "折りたたむ",
    "island_exit": "MacIsland を終了", "island_settings": "設定", "island_preferences": "環境設定...",
    // Misc
    "today": "今日", "yesterday": "昨日", "minutes": "分", "hours": "時間", "days": "日",
]
