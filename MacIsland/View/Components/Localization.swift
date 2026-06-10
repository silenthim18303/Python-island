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
    static var taboverview: String { t("tab_overview")}
    static var tabmusic: String { t("tab_music")}
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
    static var fileSearchFolder: String { t("file_search_folder") }
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
    static var musicNetease: String { t("music_netease") }
    static var musicQQ: String { t("music_qq") }
    static var musicKugou: String { t("music_kugou") }
    static var musicLRCLIB: String { t("music_lrclib") }

    // MARK: - Weather
    static var weatherTitle: String { t("weather_title") }
    static var weatherWind: String { t("weather_wind") }
    static var weatherHumidity: String { t("weather_humidity") }
    static var weatherAuto: String { t("weather_auto") }
    static var weatherCity: String { t("weather_city") }
    static var weatherAPIKey: String { t("weather_api_key") }
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
    static var aiSettings: String { t("ai_settings") }
    static var aiSettingsDesc: String { t("ai_settings_desc") }
    static var aiTTS: String { t("ai_tts") }
    static var aiTTSDesc: String { t("ai_tts_desc") }
    static var aiSTT: String { t("ai_stt") }
    static var aiSTTDesc: String { t("ai_stt_desc") }

    // MARK: - Settings
    static var settingsGeneral: String { t("settings_general") }
    static var settingsShortcuts: String { t("settings_shortcuts") }
    static var voiceTitle: String { t("voice_title") }
    static var voiceControl: String { t("voice_control") }
    static var voiceSpeech: String { t("voice_speech") }
    static var voiceCommands: String { t("voice_commands") }
    static var voiceEnableControl: String { t("voice_enable_control") }
    static var voiceEnableControlDesc: String { t("voice_enable_control_desc") }
    static var voiceEnableSpeech: String { t("voice_enable_speech") }
    static var voiceEnableSpeechDesc: String { t("voice_enable_speech_desc") }
    static var voiceWakeWord: String { t("voice_wake_word") }
    static var voiceCurrentWakeWord: String { t("voice_current_wake_word") }
    static var voiceWakeWordHint: String { t("voice_wake_word_hint") }
    static var voiceViewAll: String { t("voice_view_all") }
    static var voiceTest: String { t("voice_test") }
    static var voiceStartListening: String { t("voice_start_listening") }
    static var voiceStopListening: String { t("voice_stop_listening") }
    static var voiceRecognitionResult: String { t("voice_recognition_result") }
    static var voiceTestSpeech: String { t("voice_test_speech") }
    static var voiceTestText: String { t("voice_test_text") }
    static var voiceDone: String { t("voice_done") }
    static var voiceAdvancedConfig: String { t("voice_advanced_config") }

    // MARK: - TTS Config
    static var voiceTTSConfig: String { t("voice_tts_config") }
    static var voiceTTSVoice: String { t("voice_tts_voice") }
    static var voiceTTSSpeed: String { t("voice_tts_speed") }
    static var voiceTTSPitch: String { t("voice_tts_pitch") }
    static var voiceTTSVolume: String { t("voice_tts_volume") }
    static var voiceCurrentConfig: String { t("voice_current_config") }

    // MARK: - STT Config
    static var voiceSTTConfig: String { t("voice_stt_config") }
    static var voiceSTTLanguage: String { t("voice_stt_language") }
    static var voiceSTTContinuous: String { t("voice_stt_continuous") }
    static var voiceSTTContinuousDesc: String { t("voice_stt_continuous_desc") }

    // MARK: - Voice Commands
    static var voiceCmdPlay: String { t("voice_cmd_play") }
    static var voiceCmdPause: String { t("voice_cmd_pause") }
    static var voiceCmdNext: String { t("voice_cmd_next") }
    static var voiceCmdPrevious: String { t("voice_cmd_previous") }
    static var voiceCmdExpand: String { t("voice_cmd_expand") }
    static var voiceCmdCollapse: String { t("voice_cmd_collapse") }
    static var voiceCmdShow: String { t("voice_cmd_show") }
    static var voiceCmdHide: String { t("voice_cmd_hide") }
    static var voiceCmdWeather: String { t("voice_cmd_weather") }
    static var voiceCmdTimer: String { t("voice_cmd_timer") }
    static var voiceCmdTodo: String { t("voice_cmd_todo") }
    static var voiceCmdHelp: String { t("voice_cmd_help") }
    static var voiceCmdStock: String { t("voice_cmd_stock") }
    static var voiceCmdPlayDesc: String { t("voice_cmd_play_desc") }
    static var voiceCmdPauseDesc: String { t("voice_cmd_pause_desc") }
    static var voiceCmdNextDesc: String { t("voice_cmd_next_desc") }
    static var voiceCmdPreviousDesc: String { t("voice_cmd_previous_desc") }
    static var voiceCmdExpandDesc: String { t("voice_cmd_expand_desc") }
    static var voiceCmdCollapseDesc: String { t("voice_cmd_collapse_desc") }
    static var voiceCmdShowDesc: String { t("voice_cmd_show_desc") }
    static var voiceCmdHideDesc: String { t("voice_cmd_hide_desc") }
    static var voiceCmdWeatherDesc: String { t("voice_cmd_weather_desc") }
    static var voiceCmdTimerDesc: String { t("voice_cmd_timer_desc") }
    static var voiceCmdTodoDesc: String { t("voice_cmd_todo_desc") }
    static var voiceCmdHelpDesc: String { t("voice_cmd_help_desc") }
    static var voiceCmdStockDesc: String { t("voice_cmd_stock_desc") }

    // MARK: - Voice State
    static var voiceStateIdle: String { t("voice_state_idle") }
    static var voiceStateListening: String { t("voice_state_listening") }
    static var voiceStateProcessing: String { t("voice_state_processing") }
    static var voiceStateSpeaking: String { t("voice_state_speaking") }
    static var voiceStateError: String { t("voice_state_error") }

    // MARK: - Voice Responses
    static var voiceResponseHere: String { t("voice_response_here") }
    static var voiceResponseUnknown: String { t("voice_response_unknown") }
    static var voiceResponsePlaying: String { t("voice_response_playing") }
    static var voiceResponsePaused: String { t("voice_response_paused") }
    static var voiceResponseNext: String { t("voice_response_next") }
    static var voiceResponsePrevious: String { t("voice_response_previous") }
    static var voiceResponseExpanded: String { t("voice_response_expanded") }
    static var voiceResponseCollapsed: String { t("voice_response_collapsed") }
    static var voiceResponseShown: String { t("voice_response_shown") }
    static var voiceResponseHidden: String { t("voice_response_hidden") }
    static var voiceResponseFetchingWeather: String { t("voice_response_fetching_weather") }
    static var voiceResponseTimerIdle: String { t("voice_response_timer_idle") }
    static var voiceResponseTodoDev: String { t("voice_response_todo_dev") }
    static var voiceResponseHelp: String { t("voice_response_help") }
    static func voiceResponseTimerRemaining(minutes: Int) -> String {
        t("voice_response_timer_remaining").replacingOccurrences(of: "%d", with: "\(minutes)")
    }

    // MARK: - AI Voice Chat
    static var aiVoiceChatTitle: String { t("ai_voice_chat_title") }
    static var aiVoiceChatEmpty: String { t("ai_voice_chat_empty") }
    static var aiVoiceChatHint: String { t("ai_voice_chat_hint") }
    static var aiVoiceChatSpeak: String { t("ai_voice_chat_speak") }
    static var aiVoiceChatStop: String { t("ai_voice_chat_stop") }
    static var aiVoiceChatType: String { t("ai_voice_chat_type") }
    static var aiVoiceChatClear: String { t("ai_voice_chat_clear") }
    static var aiVoiceChatPlaceholder: String { t("ai_voice_chat_placeholder") }
    static var aiVoiceChatReady: String { t("ai_voice_chat_ready") }
    static var aiVoiceChatListening: String { t("ai_voice_chat_listening") }
    static var aiVoiceChatThinking: String { t("ai_voice_chat_thinking") }
    static func aiVoiceChatError(_ error: String) -> String {
        t("ai_voice_chat_error").replacingOccurrences(of: "%@", with: error)
    }

    static var settingsAbout: String { t("settings_about") }
    static var settingsAutostart: String { t("settings_autostart") }
    static var settingsOpacity: String { t("settings_opacity") }
    static var settingsWallpaperOpacity: String { t("settings_wallpaper_opacity") }
    static var settingsWidgetAppearance: String { t("settings_widget_appearance") }
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
    static var timerResume: String { t("timer_resume") }
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

    // MARK: - AI Extended
    static var aiQuickStart: String { t("ai_quick_start") }
    static var aiCloud: String { t("ai_cloud") }
    static var aiLocalModels: String { t("ai_local_models") }
    static var aiModelName: String { t("ai_model_name") }
    static var aiThinking: String { t("ai_thinking") }
    static var aiNoConfig: String { t("ai_no_config") }
    static var aiProtocol: String { t("ai_protocol") }

    // MARK: - Wallpaper Extended
    static var wallpaperCommunity: String { t("wallpaper_community") }
    static var wallpaperCommunityUpload: String { t("wallpaper_community_upload") }
    static var wallpaperRefresh: String { t("wallpaper_refresh") }
    static var wallpaperDownloaded: String { t("wallpaper_downloaded") }
    static var wallpaperDownloading: String { t("wallpaper_downloading") }
    static var wallpaperPrivate: String { t("wallpaper_private") }
    static var wallpaperRemovePrivate: String { t("wallpaper_remove_private") }
    static var wallpaperUploading: String { t("wallpaper_uploading") }
    static var wallpaperGitHub: String { t("wallpaper_github") }
    static var wallpaperGitHubUser: String { t("wallpaper_github_user") }
    static var wallpaperGitHubLogin: String { t("wallpaper_github_login") }
    static var wallpaperSelectHint: String { t("wallpaper_select_hint") }
    static var wallpaperRecommended: String { t("wallpaper_recommended") }
    static var wallpaperFilterAll: String { t("wallpaper_filter_all") }
    static var wallpaperFilterMine: String { t("wallpaper_filter_mine") }

    // MARK: - Event Extended
    static var eventTrack: String { t("event_track") }

    // MARK: - Alarm Extended
    static var alarmSet: String { t("alarm_set") }
    static var alarmDaily: String { t("alarm_daily") }
    static var alarmTimeUp: String { t("alarm_time_up") }

    // MARK: - Break Extended
    static var break30: String { t("break_30") }
    static var break45: String { t("break_45") }
    static var break60: String { t("break_60") }
    static var break90: String { t("break_90") }
    static var break120: String { t("break_120") }

    // MARK: - Encoding Extended
    static var encodingToLabel: String { t("encoding_to_label") }

    // MARK: - Notification Extended
    static var notifDNDFrom: String { t("notif_dnd_from") }
    static var notifDNDTo: String { t("notif_dnd_to") }

    // MARK: - Shortcut Extended
    static var shortcutAuth: String { t("shortcut_auth") }

    // MARK: - Wallpaper Extended 2
    static var wallpaperClose: String { t("wallpaper_close") }
    static var wallpaperDelete: String { t("wallpaper_delete") }
    static var wallpaperUploadFail: String { t("wallpaper_upload_fail") }
    static var wallpaperUploadSuccess: String { t("wallpaper_upload_success") }
    static var wallpaperSetPrivate: String { t("wallpaper_set_private") }
    static var wallpaperStatic: String { t("wallpaper_static") }
    static var wallpaperVideo: String { t("wallpaper_video") }
    static var wallpaperImage: String { t("wallpaper_image") }
    static var wallpaperDownload: String { t("wallpaper_download") }
    static var wallpaperLoading: String { t("wallpaper_loading") }
    static var wallpaperUsernameRequired: String { t("wallpaper_username_required") }
    static var wallpaperPRConfirm: String { t("wallpaper_pr_confirm") }

    // MARK: - Timer Extended
    static var timerSkip: String { t("timer_skip") }
    static var timerMin: String { t("timer_min") }
    static var timerSec: String { t("timer_sec") }
    static var timerHour: String { t("timer_hour") }

    // MARK: - Monitor Extended
    static var monitorCores: String { t("monitor_cores") }
    static var monitorCycles: String { t("monitor_cycles") }
    static var monitorIdle: String { t("monitor_idle") }
    static var monitorCapacity: String { t("monitor_capacity") }
    static var monitorUsed: String { t("monitor_used") }
    static var monitorCompressed: String { t("monitor_compressed") }
    static var monitorSystem: String { t("monitor_system") }
    static var monitorUser: String { t("monitor_user") }
    static var monitorApp: String { t("monitor_app") }
    static var monitorCharging: String { t("monitor_charging") }
    static var monitorRemaining: String { t("monitor_remaining") }

    // MARK: - Date Format
    static var dateFormatWeekday: String { t("date_format_weekday") }

    // MARK: - Misc Extended
    static var closePanel: String { t("close_panel") }
    static var collapseOverview: String { t("collapse_overview") }
    static var skip: String { t("skip") }

    // MARK: - Menu Bar
    static var menuHideIsland: String { t("menu_hide_island") }
    static var menuShowIsland: String { t("menu_show_island") }
    static var menuCollapse: String { t("menu_collapse") }
    static var menuCheckForUpdates: String { t("menu_check_for_updates") }
    static var menuSettings: String { t("menu_settings") }
    static var menuQuit: String { t("menu_quit") }

    // MARK: - Update
    static var updateAvailableTitle: String { t("update_available_title") }
    static func updateAvailableMessage(version: String) -> String {
        t("update_available_message").replacingOccurrences(of: "%@", with: version)
    }
    static var updateDownload: String { t("update_download") }
    static var updateLater: String { t("update_later") }
    static var updateUpToDateTitle: String { t("update_up_to_date_title") }
    static var updateUpToDateMessage: String { t("update_up_to_date_message") }
    static var updateErrorTitle: String { t("update_error_title") }

    // MARK: - Service Errors
    static var errorClipboardLink: String { t("error_clipboard_link") }
    static var errorWeatherLocation: String { t("error_weather_location") }
    static var errorWeatherFetch: String { t("error_weather_fetch") }
    static var errorWeatherAPIKey: String { t("error_weather_api_key") }
    static var errorLyricsNotFound: String { t("error_lyrics_not_found") }
    static var errorAIConnection: String { t("error_ai_connection") }
    static var errorAIRequest: String { t("error_ai_request") }
    static var errorGitHubLogin: String { t("error_github_login") }
    static var errorGitHubToken: String { t("error_github_token") }
    static var errorGitHubSize: String { t("error_github_size") }
    static var errorGitHubVideo: String { t("error_github_video") }
    static var errorGitHubCompress: String { t("error_github_compress") }
    static var errorGitHubBranch: String { t("error_github_branch") }
    static var errorGitHubBranchNotFound: String { t("error_github_branch_not_found") }
    static var errorGitHubBranchInfo: String { t("error_github_branch_info") }
    static var errorGitHubFileCreate: String { t("error_github_file_create") }
    static var errorGitHubFileInfo: String { t("error_github_file_info") }
    static var errorGitHubFileDelete: String { t("error_github_file_delete") }
    static var errorGitHubPR: String { t("error_github_pr") }
    static var errorGitHubRepo: String { t("error_github_repo") }
    static var errorGitHubPermission: String { t("error_github_permission") }
    static var errorGitHubHTTP: String { t("error_github_http") }
    static var errorGitHubNetwork: String { t("error_github_network") }

    // MARK: - Timer Notifications
    static var timerNotifCountdown: String { t("timer_notif_countdown") }
    static var timerNotifTimeUp: String { t("timer_notif_time_up") }
    static var timerNotifFocusEnd: String { t("timer_notif_focus_end") }
    static var timerNotifBreakEnd: String { t("timer_notif_break_end") }
    static var timerNotifRest: String { t("timer_notif_rest") }

    // MARK: - AI System
    static var aiSystemPrompt: String { t("ai_system_prompt") }

    // MARK: - Default Values
    static var defaultAlarmLabel: String { t("default_alarm_label") }

    // MARK: - Navigation Tab Names
    static var navSettings: String { t("nav_settings") }
    static var navTools: String { t("nav_tools") }

    // MARK: - Setting Descriptions
    static var descAppearanceMode: String { t("desc_appearance_mode") }
    static var descAccentColor: String { t("desc_accent_color") }
    static var descLanguage: String { t("desc_language") }
    static var descAutostart: String { t("desc_autostart") }
    static var descIslandOpacity: String { t("desc_island_opacity") }
    static var descWallpaperOpacity: String { t("desc_wallpaper_opacity") }
    static var descWidgetAppearance: String { t("desc_widget_appearance") }
    static var descWallpaperPath: String { t("desc_wallpaper_path") }
    static var descAnimationSpeed: String { t("desc_animation_speed") }
    static var descSpringAnimation: String { t("desc_spring_animation") }
    static var descLinkDetect: String { t("desc_link_detect") }
    static var descUrlMode: String { t("desc_url_mode") }
    static var descBlacklist: String { t("desc_blacklist") }
    static var descDnd: String { t("desc_dnd") }
    static var descDndTime: String { t("desc_dnd_time") }
    static var descLyricsSource: String { t("desc_lyrics_source") }
    static var descWeatherAPIKey: String { t("desc_weather_api_key") }
    static var descWeatherCity: String { t("desc_weather_city") }
    static var descWeatherLocationID: String { t("desc_weather_location_id") }
    static var descUsername: String { t("desc_username") }
    static var descHotkeyBindings: String { t("desc_hotkey_bindings") }

    // MARK: - Stock
      static var marketAShare: String { t("market_a_share") }
      static var marketUS: String { t("market_us") }
      static var marketHK: String { t("market_hk") }
      static var stockTitle: String { t("stock_title") }
      static var stockSearch: String { t("stock_search") }
      static var stockSearchAction: String { t("stock_search_action") }
      static var stockWatchlist: String { t("stock_watchlist") }
      static var stockAdd: String { t("stock_add") }
      static var stockRemove: String { t("stock_remove") }
      static var stockPrice: String { t("stock_price") }
      static var stockChange: String { t("stock_change") }
      static var stockNoData: String { t("stock_no_data") }
      static var stockSettings: String { t("stock_settings") }
      static var stockAutoRefresh: String { t("stock_auto_refresh") }
      static var stockRefreshFreq: String { t("stock_refresh_freq") }
      static var stockWatchlistManage: String { t("stock_watchlist_manage") }
      static var stockManageWatchlist: String { t("stock_manage_watchlist") }
      static var stockAllMarkets: String { t("stock_all_markets") }
      static var stockSearchResults: String { t("stock_search_results") }
      static var stockNoResults: String { t("stock_no_results") }
      static var stockAdded: String { t("stock_added") }
      static var stockSearchAbove: String { t("stock_search_above") }
      static var stockNoMarketStocks: String { t("stock_no_market_stocks") }

    // MARK: - Date Format
    static var dateFormatCN: String { t("date_format_cn") }
    static var dateFormatShort: String { t("date_format_short") }

    /// 当前语言对应的 Locale identifier
    static var localeIdentifier: String {
        switch LocalizationManager.shared.currentLanguage {
        case .zh: return "zh_CN"
        case .en: return "en_US"
        case .ja: return "ja_JP"
        }
    }
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
    "tab_overview":"概览", "tab_music":"音乐",
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
    "file_search_folder": "选择搜索目录",
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
    "music_netease": "网易云", "music_qq": "QQ 音乐", "music_kugou": "酷狗", "music_lrclib": "LRCLIB",
    // Weather
    "weather_title": "天气", "weather_wind": "风速", "weather_humidity": "湿度",
    "weather_auto": "自动定位", "weather_city": "手动城市", "weather_api_key": "和风天气 API Key", "weather_location_id": "Location ID",
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
    "ai_settings": "AI 服务设置", "ai_settings_desc": "配置 AI 服务地址和模型",
    "ai_tts": "语音合成", "ai_tts_desc": "配置 TTS 语音、语速、音调",
    "ai_stt": "语音识别", "ai_stt_desc": "配置 STT 识别语言和连续模式",
    // Settings
    "settings_general": "通用", "settings_shortcuts": "快捷键", "voice_title": "语音操作",
    "voice_control": "语音控制", "voice_speech": "语音播报", "voice_commands": "语音指令",
    "voice_enable_control": "启用语音控制", "voice_enable_control_desc": "使用语音指令控制灵动岛",
    "voice_enable_speech": "启用语音播报", "voice_enable_speech_desc": "播报天气、计时器、通知等信息",
    "voice_wake_word": "唤醒词", "voice_current_wake_word": "当前唤醒词",
    "voice_wake_word_hint": "说出唤醒词后，再说出指令。例如：「嘿，灵动岛，播放音乐」",
    "voice_view_all": "查看全部", "voice_test": "测试",
    "voice_start_listening": "开始监听", "voice_stop_listening": "停止监听",
    "voice_recognition_result": "识别结果", "voice_test_speech": "测试语音播报",
    "voice_test_text": "你好，我是 MacIsland 灵动岛助手", "voice_done": "完成",
    "voice_advanced_config": "高级语音配置",
    // TTS Config
    "voice_tts_config": "语音合成配置",
    "voice_tts_voice": "语音",
    "voice_tts_speed": "语速",
    "voice_tts_pitch": "音调",
    "voice_tts_volume": "音量",
    "voice_current_config": "当前配置",
    // STT Config
    "voice_stt_config": "语音识别配置",
    "voice_stt_language": "识别语言",
    "voice_stt_continuous": "连续识别",
    "voice_stt_continuous_desc": "持续监听语音输入",
    // Voice Commands
    "voice_cmd_play": "播放", "voice_cmd_pause": "暂停", "voice_cmd_next": "下一首", "voice_cmd_previous": "上一首",
    "voice_cmd_expand": "展开", "voice_cmd_collapse": "收起", "voice_cmd_show": "显示", "voice_cmd_hide": "隐藏",
    "voice_cmd_weather": "天气", "voice_cmd_timer": "计时器", "voice_cmd_todo": "待办", "voice_cmd_help": "帮助", "voice_cmd_stock": "股票",
    "voice_cmd_play_desc": "播放音乐", "voice_cmd_pause_desc": "暂停音乐",
    "voice_cmd_next_desc": "下一首歌曲", "voice_cmd_previous_desc": "上一首歌曲",
    "voice_cmd_expand_desc": "展开灵动岛", "voice_cmd_collapse_desc": "收起灵动岛",
    "voice_cmd_show_desc": "显示灵动岛", "voice_cmd_hide_desc": "隐藏灵动岛",
    "voice_cmd_weather_desc": "播报天气", "voice_cmd_timer_desc": "播报计时器状态",
    "voice_cmd_todo_desc": "播报待办事项", "voice_cmd_help_desc": "显示帮助", "voice_cmd_stock_desc": "播报股票行情",
    // Voice State
    "voice_state_idle": "空闲", "voice_state_listening": "监听中",
    "voice_state_processing": "处理中", "voice_state_speaking": "播报中", "voice_state_error": "错误",
    // Voice Responses
    "voice_response_here": "我在", "voice_response_unknown": "抱歉，我没有理解您的指令",
    "voice_response_playing": "正在播放", "voice_response_paused": "已暂停",
    "voice_response_next": "下一首", "voice_response_previous": "上一首",
    "voice_response_expanded": "已展开", "voice_response_collapsed": "已收起",
    "voice_response_shown": "已显示", "voice_response_hidden": "已隐藏",
    "voice_response_fetching_weather": "正在获取天气信息",
    "voice_response_timer_remaining": "番茄钟还剩%d分钟", "voice_response_timer_idle": "计时器空闲中",
    "voice_response_todo_dev": "待办功能开发中",
    "voice_response_help": "您可以说：播放、暂停、下一首、展开、收起、天气、计时器等指令",
    // AI Voice Chat
    "ai_voice_chat_title": "AI 语音对话",
    "ai_voice_chat_empty": "开始与 AI 对话",
    "ai_voice_chat_hint": "点击麦克风按钮说话，或使用键盘输入",
    "ai_voice_chat_speak": "按住说话",
    "ai_voice_chat_stop": "松开结束",
    "ai_voice_chat_type": "键盘输入",
    "ai_voice_chat_clear": "清除对话",
    "ai_voice_chat_placeholder": "输入消息...",
    "ai_voice_chat_ready": "就绪",
    "ai_voice_chat_listening": "正在听...",
    "ai_voice_chat_thinking": "思考中...",
    "ai_voice_chat_error": "错误：%@",
    "settings_about": "关于",
    "settings_autostart": "开机自启动", "settings_opacity": "灵动岛透明度",
    "settings_wallpaper_opacity": "壁纸透明度", "settings_widget_appearance": "小组件外观",
    "settings_animation": "动画",
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
    "timer_start": "开始", "timer_pause": "暂停", "timer_resume": "继续", "timer_stop": "停止",
    // Monitor
    "monitor_title": "系统监控", "monitor_cpu": "CPU", "monitor_memory": "内存",
    "monitor_disk": "磁盘", "monitor_battery": "电池", "monitor_network": "网络",
    // Island
    "island_hide": "隐藏灵动岛", "island_show": "显示灵动岛", "island_collapse": "折叠岛",
    "island_exit": "退出 MacIsland", "island_settings": "设置", "island_preferences": "偏好设置...",
    // Misc
    "today": "今天", "yesterday": "昨天", "minutes": "分钟", "hours": "小时", "days": "天",
    // AI Extended
    "ai_quick_start": "快速开始 (Ollama):", "ai_cloud": "云端: OpenAI / DeepSeek / Moonshot / 通义千问 / 零一万物 / Together / Groq",
    "ai_local_models": "本地: Ollama / llama.cpp / LM Studio / vLLM", "ai_model_name": "模型名称",
    "ai_thinking": "思考中...", "ai_no_config": "请先配置 AI 服务\n点击右上角 ⚙ 按钮",
    "ai_protocol": "有 API Key → OpenAI 兼容协议（/v1/chat/completions）\n无 API Key → Ollama 协议（/api/chat）",
    // Wallpaper Extended
    "wallpaper_community": "社区壁纸", "wallpaper_community_upload": "社区上传",
    "wallpaper_refresh": "点击刷新获取社区壁纸", "wallpaper_downloaded": "已下载", "wallpaper_downloading": "下载中…",
    "wallpaper_private": "私有", "wallpaper_remove_private": "取消私有", "wallpaper_uploading": "上传中...",
    "wallpaper_github": "GitHub 登录", "wallpaper_github_user": "GitHub 用户名",
    "wallpaper_github_login": "请在浏览器中输入此代码",
    "wallpaper_select_hint": "或点击下方按钮选择", "wallpaper_recommended": "建议 1920×1080 以上",
    "wallpaper_filter_all": "全部", "wallpaper_filter_mine": "我的",
    // Event Extended
    "event_track": "追踪重要日期：纪念日、生日、节日、考试",
    // Alarm Extended
    "alarm_set": "设置提醒闹钟，支持每日重复", "alarm_daily": "每日",
    "alarm_time_up": "时间到！",
    // Break Extended
    "break_30": "30 分钟", "break_45": "45 分钟", "break_60": "60 分钟",
    "break_90": "90 分钟", "break_120": "120 分钟",
    // Encoding Extended
    "encoding_to_label": "至",
    // Notification Extended
    "notif_dnd_from": "从", "notif_dnd_to": "至",
    // Shortcut Extended
    "shortcut_auth": "授权",
    // Wallpaper Extended 2
    "wallpaper_close": "关闭壁纸", "wallpaper_delete": "删除",
    "wallpaper_upload_fail": "上传失败", "wallpaper_upload_success": "已提交审核",
    "wallpaper_set_private": "设为私有", "wallpaper_static": "静态壁纸",
    "wallpaper_video": "视频", "wallpaper_image": "图片",
    "wallpaper_download": "下载", "wallpaper_loading": "加载中...",
    "wallpaper_username_required": "请先设置用户名",
    "wallpaper_pr_confirm": "确定要删除吗？此操作将提交 PR 至仓库审核。",
    // Timer Extended
    "timer_skip": "跳过", "timer_min": "分", "timer_sec": "秒", "timer_hour": "时",
    // Monitor Extended
    "monitor_cores": "核", "monitor_cycles": "次",
    "monitor_idle": "空闲", "monitor_capacity": "容量",
    "monitor_system": "系统", "monitor_user": "用户",
    "monitor_app": "应用", "monitor_charging": "充电中", "monitor_remaining": "剩余",
    "monitor_used": "已用", "monitor_compressed": "压缩",
    // Date Format
    "date_format_weekday": "周",
    // Misc Extended
    "close_panel": "关闭", "collapse_overview": "收起到概览", "skip": "跳过",
    // Menu Bar
    "menu_hide_island": "隐藏灵动岛", "menu_show_island": "显示灵动岛",
    "menu_collapse": "折叠岛", "menu_check_for_updates": "检查更新", "menu_settings": "设置", "menu_quit": "退出 MacIsland",
    // Update
    "update_available_title": "发现新版本",
    "update_available_message": "MacIsland %@ 已发布，是否立即更新？",
    "update_download": "下载更新",
    "update_later": "稍后提醒",
    "update_up_to_date_title": "检查更新",
    "update_up_to_date_message": "当前已是最新版本！",
    "update_error_title": "检查更新失败",
    // Service Errors
    "error_clipboard_link": "🔗 链接检测",
    "error_weather_location": "获取位置失败", "error_weather_fetch": "获取天气失败", "error_weather_api_key": "请先配置和风天气 API Key",
    "error_lyrics_not_found": "未找到歌词",
    "error_ai_connection": "连接失败", "error_ai_request": "API 请求失败",
    "error_github_login": "请先登录 GitHub", "error_github_token": "请先在设置中登录 GitHub",
    "error_github_size": "文件大小超过 100MB 限制", "error_github_video": "无法读取视频文件",
    "error_github_compress": "图片压缩失败",
    "error_github_branch": "创建分支失败",
    "error_github_branch_not_found": "分支不存在，请先在仓库中创建至少一个提交",
    "error_github_branch_info": "无法读取分支信息",
    "error_github_file_create": "文件创建失败", "error_github_file_info": "无法获取文件信息",
    "error_github_file_delete": "文件删除失败", "error_github_pr": "创建 PR 失败",
    "error_github_repo": "社区仓库暂未开放，请稍后再试",
    "error_github_permission": "权限不足（HTTP 403），请确认 Token 有 repo 权限",
    "error_github_http": "服务器返回 HTTP", "error_github_network": "网络错误",
    // Timer Notifications
    "timer_notif_countdown": "⏱ 倒计时提醒", "timer_notif_time_up": "⏱ 倒计时",
    "timer_notif_focus_end": "🍅 专注结束", "timer_notif_break_end": "🍅 休息结束",
    "timer_notif_rest": "休息一下吧，已完成",
    // AI System
    "ai_system_prompt": "你是 MacIsland 的 AI 助手。简洁、友好、有帮助。",
    // Default Values
    "default_alarm_label": "闹钟",
    // Navigation
    "nav_settings": "设置", "nav_tools": "工具",
    // Stock
    "market_a_share": "A股", "market_us": "美股", "market_hk": "港股",
    "stock_title": "股票",
    "stock_search": "搜索股票",
    "stock_search_action": "搜索",
    "stock_watchlist": "自选股",
    "stock_add": "添加",
    "stock_remove": "移除",
    "stock_price": "价格",
    "stock_change": "涨跌幅",
    "stock_no_data": "暂无股票数据",
    "stock_settings": "股票设置",
    "stock_auto_refresh": "自动刷新",
    "stock_refresh_freq": "刷新频率",
    "stock_watchlist_manage": "自选股管理",
    "stock_manage_watchlist": "管理自选股",
    "stock_all_markets": "全部",
    "stock_search_results": "搜索结果",
    "stock_no_results": "未找到匹配的股票",
    "stock_added": "已添加",
    "stock_search_above": "在上方搜索框输入股票代码或名称",
    "stock_no_market_stocks": "该市场暂无自选股",
    // Date Format
    "date_format_cn": "yyyy年M月d日 EEEE",
    "date_format_short": "M/d EEEE",
    // Setting Descriptions
    "desc_appearance_mode": "切换深色/浅色/跟随系统主题，设置窗口和菜单栏即时生效。",
    "desc_accent_color": "自定义界面强调色，9 种预设色可选，全局即时生效。",
    "desc_language": "切换界面显示语言，支持中文/English/日本語。",
    "desc_autostart": "登录系统后自动启动 MacIsland。",
    "desc_island_opacity": "调整灵动岛整体不透明度（10%–100%）。",
    "desc_wallpaper_opacity": "独立于灵动岛整体透明度的壁纸不透明度。",
    "desc_widget_appearance": "设置小组件的深浅色模式，可选择跟随灵动岛或独立设置。",
    "desc_wallpaper_path": "自定义壁纸缓存目录，留空使用默认位置。",
    "desc_animation_speed": "灵动岛展开/折叠的过渡时长。",
    "desc_spring_animation": "启用更有弹性的弹簧过渡曲线。",
    "desc_link_detect": "复制链接时在灵动岛快速提示。",
    "desc_url_mode": "选择被识别为链接的 URL 形式。",
    "desc_blacklist": "命中黑名单的域名不会触发链接提示。",
    "desc_dnd": "在指定时段内静默所有灵动岛通知。",
    "desc_dnd_time": "设置免打扰的开始和结束时间。",
    "desc_lyrics_source": "优先使用的歌词数据来源。",
    "desc_weather_api_key": "和风天气 API Key（免费注册 qweather.com 获取）。保存在系统钥匙串，不写入 UserDefaults。",
    "desc_weather_city": "指定城市名，留空则自动定位。",
    "desc_weather_location_id": "和风天气城市 ID，配合手动城市使用。",
    "desc_username": "上传社区壁纸时显示的作者名。",
    "desc_hotkey_bindings": "自定义显示/播放控制等全局热键。",
]

// MARK: - 英文翻译

private let enStrings: [String: String] = [
    // Tab
    "tab_overview":"Overview", "tab_music":"Music",
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
    "file_search_folder": "Choose Search Folder",
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
    "music_netease": "NetEase", "music_qq": "QQ Music", "music_kugou": "Kugou", "music_lrclib": "LRCLIB",
    // Weather
    "weather_title": "Weather", "weather_wind": "Wind", "weather_humidity": "Humidity",
    "weather_auto": "Auto Locate", "weather_city": "Manual City", "weather_api_key": "QWeather API Key", "weather_location_id": "Location ID",
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
    "ai_settings": "AI Service Settings", "ai_settings_desc": "Configure AI server and model",
    "ai_tts": "Text-to-Speech", "ai_tts_desc": "Configure TTS voice, speed, pitch",
    "ai_stt": "Speech-to-Text", "ai_stt_desc": "Configure STT language and continuous mode",
    // Settings
    "settings_general": "General", "settings_shortcuts": "Shortcuts", "voice_title": "Voice Control",
    "voice_control": "Voice Control", "voice_speech": "Voice Speech", "voice_commands": "Voice Commands",
    "voice_enable_control": "Enable Voice Control", "voice_enable_control_desc": "Use voice commands to control the island",
    "voice_enable_speech": "Enable Voice Speech", "voice_enable_speech_desc": "Announce weather, timer, notifications, etc.",
    "voice_wake_word": "Wake Word", "voice_current_wake_word": "Current Wake Word",
    "voice_wake_word_hint": "Say the wake word followed by a command. E.g., \"Hey Island, play music\"",
    "voice_view_all": "View All", "voice_test": "Test",
    "voice_start_listening": "Start Listening", "voice_stop_listening": "Stop Listening",
    "voice_recognition_result": "Recognition Result", "voice_test_speech": "Test Voice Speech",
    "voice_test_text": "Hello, I am MacIsland assistant", "voice_done": "Done",
    "voice_advanced_config": "Advanced Voice Config",
    // TTS Config
    "voice_tts_config": "Text-to-Speech Config",
    "voice_tts_voice": "Voice",
    "voice_tts_speed": "Speed",
    "voice_tts_pitch": "Pitch",
    "voice_tts_volume": "Volume",
    "voice_current_config": "Current Config",
    // STT Config
    "voice_stt_config": "Speech-to-Text Config",
    "voice_stt_language": "Recognition Language",
    "voice_stt_continuous": "Continuous Recognition",
    "voice_stt_continuous_desc": "Continuously listen for voice input",
    // Voice Commands
    "voice_cmd_play": "Play", "voice_cmd_pause": "Pause", "voice_cmd_next": "Next", "voice_cmd_previous": "Previous",
    "voice_cmd_expand": "Expand", "voice_cmd_collapse": "Collapse", "voice_cmd_show": "Show", "voice_cmd_hide": "Hide",
    "voice_cmd_weather": "Weather", "voice_cmd_timer": "Timer", "voice_cmd_todo": "Todo", "voice_cmd_help": "Help", "voice_cmd_stock": "Stock",
    "voice_cmd_play_desc": "Play music", "voice_cmd_pause_desc": "Pause music",
    "voice_cmd_next_desc": "Next track", "voice_cmd_previous_desc": "Previous track",
    "voice_cmd_expand_desc": "Expand island", "voice_cmd_collapse_desc": "Collapse island",
    "voice_cmd_show_desc": "Show island", "voice_cmd_hide_desc": "Hide island",
    "voice_cmd_weather_desc": "Announce weather", "voice_cmd_timer_desc": "Announce timer status",
    "voice_cmd_todo_desc": "Announce todos", "voice_cmd_help_desc": "Show help", "voice_cmd_stock_desc": "Announce stock prices",
    // Voice State
    "voice_state_idle": "Idle", "voice_state_listening": "Listening",
    "voice_state_processing": "Processing", "voice_state_speaking": "Speaking", "voice_state_error": "Error",
    // Voice Responses
    "voice_response_here": "I'm here", "voice_response_unknown": "Sorry, I didn't understand",
    "voice_response_playing": "Playing", "voice_response_paused": "Paused",
    "voice_response_next": "Next track", "voice_response_previous": "Previous track",
    "voice_response_expanded": "Expanded", "voice_response_collapsed": "Collapsed",
    "voice_response_shown": "Shown", "voice_response_hidden": "Hidden",
    "voice_response_fetching_weather": "Fetching weather",
    "voice_response_timer_remaining": "Pomodoro has %d minutes left", "voice_response_timer_idle": "Timer is idle",
    "voice_response_todo_dev": "Todo feature in development",
    "voice_response_help": "You can say: play, pause, next, expand, collapse, weather, timer, etc.",
    // AI Voice Chat
    "ai_voice_chat_title": "AI Voice Chat",
    "ai_voice_chat_empty": "Start a conversation with AI",
    "ai_voice_chat_hint": "Tap the microphone to speak, or use keyboard input",
    "ai_voice_chat_speak": "Hold to speak",
    "ai_voice_chat_stop": "Release to stop",
    "ai_voice_chat_type": "Type",
    "ai_voice_chat_clear": "Clear",
    "ai_voice_chat_placeholder": "Type a message...",
    "ai_voice_chat_ready": "Ready",
    "ai_voice_chat_listening": "Listening...",
    "ai_voice_chat_thinking": "Thinking...",
    "ai_voice_chat_error": "Error: %@",
    "settings_about": "About",
    "settings_autostart": "Launch at Login", "settings_opacity": "Island Opacity",
    "settings_wallpaper_opacity": "Wallpaper Opacity", "settings_widget_appearance": "Widget Appearance",
    "settings_animation": "Animation",
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
    "timer_start": "Start", "timer_pause": "Pause", "timer_resume": "Resume", "timer_stop": "Stop",
    // Monitor
    "monitor_title": "System Monitor", "monitor_cpu": "CPU", "monitor_memory": "Memory",
    "monitor_disk": "Disk", "monitor_battery": "Battery", "monitor_network": "Network",
    // Island
    "island_hide": "Hide Island", "island_show": "Show Island", "island_collapse": "Collapse",
    "island_exit": "Quit MacIsland", "island_settings": "Settings", "island_preferences": "Preferences...",
    // Misc
    "today": "Today", "yesterday": "Yesterday", "minutes": "min", "hours": "hours", "days": "days",
    // AI Extended
    "ai_quick_start": "Quick Start (Ollama):", "ai_cloud": "Cloud: OpenAI / DeepSeek / Moonshot / Tongyi / Yi / Together / Groq",
    "ai_local_models": "Local: Ollama / llama.cpp / LM Studio / vLLM", "ai_model_name": "Model Name",
    "ai_thinking": "Thinking...", "ai_no_config": "Please configure AI service first\nClick ⚙ button",
    "ai_protocol": "With API Key → OpenAI compatible (/v1/chat/completions)\nWithout → Ollama (/api/chat)",
    // Wallpaper Extended
    "wallpaper_community": "Community Wallpaper", "wallpaper_community_upload": "Community Upload",
    "wallpaper_refresh": "Click to refresh community wallpapers", "wallpaper_downloaded": "Downloaded", "wallpaper_downloading": "Downloading…",
    "wallpaper_private": "Private", "wallpaper_remove_private": "Remove Private", "wallpaper_uploading": "Uploading...",
    "wallpaper_github": "GitHub Login", "wallpaper_github_user": "GitHub Username",
    "wallpaper_github_login": "Enter this code in browser",
    "wallpaper_select_hint": "Or click button below", "wallpaper_recommended": "Recommended 1920×1080+",
    "wallpaper_filter_all": "All", "wallpaper_filter_mine": "Mine",
    // Event Extended
    "event_track": "Track important dates: anniversaries, birthdays, holidays, exams",
    // Alarm Extended
    "alarm_set": "Set reminder alarm with daily repeat", "alarm_daily": "Daily",
    "alarm_time_up": "Time's up!",
    // Break Extended
    "break_30": "30 min", "break_45": "45 min", "break_60": "60 min",
    "break_90": "90 min", "break_120": "120 min",
    // Encoding Extended
    "encoding_to_label": "To",
    // Notification Extended
    "notif_dnd_from": "From", "notif_dnd_to": "To",
    // Shortcut Extended
    "shortcut_auth": "Authorize",
    // Wallpaper Extended 2
    "wallpaper_close": "Close Wallpaper", "wallpaper_delete": "Delete",
    "wallpaper_upload_fail": "Upload Failed", "wallpaper_upload_success": "Submitted for Review",
    "wallpaper_set_private": "Set Private", "wallpaper_static": "Static",
    "wallpaper_video": "Video", "wallpaper_image": "Image",
    "wallpaper_download": "Download", "wallpaper_loading": "Loading...",
    "wallpaper_username_required": "Please set username first",
    "wallpaper_pr_confirm": "Delete? This will submit a PR for review.",
    // Timer Extended
    "timer_skip": "Skip", "timer_min": "min", "timer_sec": "sec", "timer_hour": "hr",
    // Monitor Extended
    "monitor_cores": "cores", "monitor_cycles": "cycles",
    "monitor_idle": "Idle", "monitor_capacity": "Capacity",
    "monitor_system": "System", "monitor_user": "User",
    "monitor_app": "App", "monitor_charging": "Charging", "monitor_remaining": "Remaining",
    "monitor_used": "Used", "monitor_compressed": "Compressed",
    // Date Format
    "date_format_weekday": "",
    // Misc Extended
    "close_panel": "Close", "collapse_overview": "Collapse", "skip": "Skip",
    // Menu Bar
    "menu_hide_island": "Hide Island", "menu_show_island": "Show Island",
    "menu_collapse": "Collapse", "menu_check_for_updates": "Check for Updates", "menu_settings": "Settings", "menu_quit": "Quit MacIsland",
    // Update
    "update_available_title": "Update Available",
    "update_available_message": "MacIsland %@ is available. Would you like to update?",
    "update_download": "Download Update",
    "update_later": "Remind Me Later",
    "update_up_to_date_title": "Check for Updates",
    "update_up_to_date_message": "You're up to date!",
    "update_error_title": "Update Check Failed",
    // Service Errors
    "error_clipboard_link": "🔗 Link Detected",
    "error_weather_location": "Failed to get location", "error_weather_fetch": "Failed to fetch weather", "error_weather_api_key": "Please configure QWeather API Key first",
    "error_lyrics_not_found": "Lyrics not found",
    "error_ai_connection": "Connection failed", "error_ai_request": "API request failed",
    "error_github_login": "Please login to GitHub first", "error_github_token": "Please login to GitHub in settings first",
    "error_github_size": "File size exceeds 100MB limit", "error_github_video": "Cannot read video file",
    "error_github_compress": "Image compression failed",
    "error_github_branch": "Failed to create branch",
    "error_github_branch_not_found": "Branch not found, please create at least one commit in the repo first",
    "error_github_branch_info": "Cannot read branch info",
    "error_github_file_create": "File creation failed", "error_github_file_info": "Cannot get file info",
    "error_github_file_delete": "File deletion failed", "error_github_pr": "PR creation failed",
    "error_github_repo": "Community repo not available, please try again later",
    "error_github_permission": "Insufficient permissions (HTTP 403), please confirm Token has repo access",
    "error_github_http": "Server returned HTTP", "error_github_network": "Network error",
    // Timer Notifications
    "timer_notif_countdown": "⏱ Countdown Reminder", "timer_notif_time_up": "⏱ Countdown",
    "timer_notif_focus_end": "🍅 Focus Complete", "timer_notif_break_end": "🍅 Break Over",
    "timer_notif_rest": "Take a break, completed",
    // AI System
    "ai_system_prompt": "You are MacIsland's AI assistant. Concise, friendly, and helpful.",
    // Default Values
    "default_alarm_label": "Alarm",
    // Navigation
    "nav_settings": "Settings", "nav_tools": "Tools",
    // Stock
    "market_a_share": "A-Share", "market_us": "US", "market_hk": "HK",
    "stock_title": "Stock",
    "stock_search": "Search Stocks",
    "stock_search_action": "Search",
    "stock_watchlist": "Watchlist",
    "stock_add": "Add",
    "stock_remove": "Remove",
    "stock_price": "Price",
    "stock_change": "Change",
    "stock_no_data": "No stock data",
    "stock_settings": "Stock Settings",
    "stock_auto_refresh": "Auto Refresh",
    "stock_refresh_freq": "Refresh Interval",
    "stock_watchlist_manage": "Watchlist Management",
    "stock_manage_watchlist": "Manage Watchlist",
    "stock_all_markets": "All",
    "stock_search_results": "Search Results",
    "stock_no_results": "No matching stocks found",
    "stock_added": "Added",
    "stock_search_above": "Search by stock code or name above",
    "stock_no_market_stocks": "No stocks in this market",
    // Date Format
    "date_format_cn": "EEEE, MMMM d, yyyy",
    "date_format_short": "EEE, M/d",
    // Setting Descriptions
    "desc_appearance_mode": "Switch between dark/light/system theme. Takes effect immediately.",
    "desc_accent_color": "Customize accent color with 9 presets. Global instant effect.",
    "desc_language": "Switch display language. Supports Chinese/English/Japanese.",
    "desc_autostart": "Automatically launch MacIsland after login.",
    "desc_island_opacity": "Adjust island opacity (10%–100%).",
    "desc_wallpaper_opacity": "Wallpaper opacity independent of island opacity.",
    "desc_widget_appearance": "Set widget light/dark mode, can follow island or set independently.",
    "desc_wallpaper_path": "Custom wallpaper cache directory. Leave empty for default.",
    "desc_animation_speed": "Transition duration for expand/collapse animations.",
    "desc_spring_animation": "Enable bouncy spring animation curves.",
    "desc_link_detect": "Show quick notification when copying links.",
    "desc_url_mode": "Choose which URL formats are recognized as links.",
    "desc_blacklist": "Domains in blacklist won't trigger link notifications.",
    "desc_dnd": "Silence all island notifications during specified hours.",
    "desc_dnd_time": "Set do-not-disturb start and end time.",
    "desc_lyrics_source": "Preferred lyrics data source.",
    "desc_weather_api_key": "QWeather API Key (free registration at qweather.com). Stored in Keychain, not UserDefaults.",
    "desc_weather_city": "Specify city name. Leave empty for auto location.",
    "desc_weather_location_id": "QWeather city ID, used with manual city.",
    "desc_username": "Author name shown when uploading community wallpapers.",
    "desc_hotkey_bindings": "Customize display/playback control global hotkeys.",
]

// MARK: - 日文翻译

private let jaStrings: [String: String] = [
    // Tab
    "tab_overview":"概要","tab_music":"音楽",
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
    "file_search_folder": "検索フォルダを選択",
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
    "music_netease": "NetEase", "music_qq": "QQ Music", "music_kugou": "Kugou", "music_lrclib": "LRCLIB",
    // Weather
    "weather_title": "天気", "weather_wind": "風速", "weather_humidity": "湿度",
    "weather_auto": "自動位置", "weather_city": "手動都市", "weather_api_key": "QWeather API Key", "weather_location_id": "Location ID",
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
    "ai_settings": "AI サービス設定", "ai_settings_desc": "AI サーバーとモデルを設定",
    "ai_tts": "音声合成", "ai_tts_desc": "TTS 音声・速度・ピッチを設定",
    "ai_stt": "音声認識", "ai_stt_desc": "STT 言語と連続モードを設定",
    // Settings
    "settings_general": "一般", "settings_shortcuts": "ショートカット", "voice_title": "音声操作",
    "voice_control": "音声制御", "voice_speech": "音声読み上げ", "voice_commands": "音声コマンド",
    "voice_enable_control": "音声制御を有効にする", "voice_enable_control_desc": "音声コマンドでアイランドを制御",
    "voice_enable_speech": "音声読み上げを有効にする", "voice_enable_speech_desc": "天気、タイマー、通知などを読み上げ",
    "voice_wake_word": "ウェイクワード", "voice_current_wake_word": "現在のウェイクワード",
    "voice_wake_word_hint": "ウェイクワードの後にコマンドを言ってください。例：「Hey Island、音楽再生」",
    "voice_view_all": "すべて表示", "voice_test": "テスト",
    "voice_start_listening": "リスニング開始", "voice_stop_listening": "リスニング停止",
    "voice_recognition_result": "認識結果", "voice_test_speech": "音声読み上げテスト",
    "voice_test_text": "こんにちは、MacIslandアシスタントです", "voice_done": "完了",
    "voice_advanced_config": "詳細音声設定",
    // TTS Config
    "voice_tts_config": "音声合成設定",
    "voice_tts_voice": "音声",
    "voice_tts_speed": "速度",
    "voice_tts_pitch": "ピッチ",
    "voice_tts_volume": "音量",
    "voice_current_config": "現在の設定",
    // STT Config
    "voice_stt_config": "音声認識設定",
    "voice_stt_language": "認識言語",
    "voice_stt_continuous": "連続認識",
    "voice_stt_continuous_desc": "音声入力を継続的にリスニング",
    // Voice Commands
    "voice_cmd_play": "再生", "voice_cmd_pause": "一時停止", "voice_cmd_next": "次へ", "voice_cmd_previous": "前へ",
    "voice_cmd_expand": "展開", "voice_cmd_collapse": "折りたたむ", "voice_cmd_show": "表示", "voice_cmd_hide": "隠す",
    "voice_cmd_weather": "天気", "voice_cmd_timer": "タイマー", "voice_cmd_todo": "TODO", "voice_cmd_help": "ヘルプ", "voice_cmd_stock": "株式",
    "voice_cmd_play_desc": "音楽を再生", "voice_cmd_pause_desc": "音楽を一時停止",
    "voice_cmd_next_desc": "次の曲", "voice_cmd_previous_desc": "前の曲",
    "voice_cmd_expand_desc": "アイランドを展開", "voice_cmd_collapse_desc": "アイランドを折りたたむ",
    "voice_cmd_show_desc": "アイランドを表示", "voice_cmd_hide_desc": "アイランドを隠す",
    "voice_cmd_weather_desc": "天気を読み上げ", "voice_cmd_timer_desc": "タイマー状態を読み上げ",
    "voice_cmd_todo_desc": "TODOを読み上げ", "voice_cmd_help_desc": "ヘルプを表示", "voice_cmd_stock_desc": "株価を読み上げ",
    // Voice State
    "voice_state_idle": "アイドル", "voice_state_listening": "リスニング中",
    "voice_state_processing": "処理中", "voice_state_speaking": "読み上げ中", "voice_state_error": "エラー",
    // Voice Responses
    "voice_response_here": "はい", "voice_response_unknown": "申し訳ありません、理解できませんでした",
    "voice_response_playing": "再生中", "voice_response_paused": "一時停止",
    "voice_response_next": "次の曲", "voice_response_previous": "前の曲",
    "voice_response_expanded": "展開しました", "voice_response_collapsed": "折りたたみました",
    "voice_response_shown": "表示しました", "voice_response_hidden": "隠しました",
    "voice_response_fetching_weather": "天気を取得中",
    "voice_response_timer_remaining": "ポモドーロはあと%d分です", "voice_response_timer_idle": "タイマーはアイドルです",
    "voice_response_todo_dev": "TODO機能は開発中です",
    "voice_response_help": "「再生」「一時停止」「次へ」「展開」「折りたたむ」「天気」「タイマー」などと言ってください",
    // AI Voice Chat
    "ai_voice_chat_title": "AI 音声チャット",
    "ai_voice_chat_empty": "AIとの会話を開始",
    "ai_voice_chat_hint": "マイクをタップして話すか、キーボードで入力",
    "ai_voice_chat_speak": "話す",
    "ai_voice_chat_stop": "停止",
    "ai_voice_chat_type": "入力",
    "ai_voice_chat_clear": "クリア",
    "ai_voice_chat_placeholder": "メッセージを入力...",
    "ai_voice_chat_ready": "準備完了",
    "ai_voice_chat_listening": "リスニング中...",
    "ai_voice_chat_thinking": "考え中...",
    "ai_voice_chat_error": "エラー：%@",
    "settings_about": "について",
    "settings_autostart": "ログイン時に起動", "settings_opacity": "アイランド透明度",
    "settings_wallpaper_opacity": "壁紙透明度", "settings_widget_appearance": "ウィジェット外観",
    "settings_animation": "アニメーション",
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
    "timer_start": "開始", "timer_pause": "一時停止", "timer_resume": "再開", "timer_stop": "停止",
    // Monitor
    "monitor_title": "システムモニター", "monitor_cpu": "CPU", "monitor_memory": "メモリ",
    "monitor_disk": "ディスク", "monitor_battery": "バッテリー", "monitor_network": "ネットワーク",
    // Island
    "island_hide": "アイランドを隠す", "island_show": "アイランドを表示", "island_collapse": "折りたたむ",
    "island_exit": "MacIsland を終了", "island_settings": "設定", "island_preferences": "環境設定...",
    // Misc
    "today": "今日", "yesterday": "昨日", "minutes": "分", "hours": "時間", "days": "日",
    // AI Extended
    "ai_quick_start": "クイックスタート (Ollama):", "ai_cloud": "クラウド: OpenAI / DeepSeek / Moonshot / Tongyi / Yi / Together / Groq",
    "ai_local_models": "ローカル: Ollama / llama.cpp / LM Studio / vLLM", "ai_model_name": "モデル名",
    "ai_thinking": "思考中...", "ai_no_config": "AI サービスを設定してください\n右上 ⚙ ボタンをクリック",
    "ai_protocol": "API Key あり → OpenAI 互換 (/v1/chat/completions)\nなし → Ollama (/api/chat)",
    // Wallpaper Extended
    "wallpaper_community": "コミュニティ壁紙", "wallpaper_community_upload": "コミュニティアップロード",
    "wallpaper_refresh": "クリックしてコミュニティ壁紙を更新", "wallpaper_downloaded": "ダウンロード済み", "wallpaper_downloading": "ダウンロード中…",
    "wallpaper_private": "プライベート", "wallpaper_remove_private": "プライベート解除", "wallpaper_uploading": "アップロード中...",
    "wallpaper_github": "GitHub ログイン", "wallpaper_github_user": "GitHub ユーザー名",
    "wallpaper_github_login": "ブラウザでこのコードを入力してください",
    "wallpaper_select_hint": "または下のボタンを選択", "wallpaper_recommended": "1920×1080 以上推奨",
    "wallpaper_filter_all": "すべて", "wallpaper_filter_mine": "自分の",
    // Event Extended
    "event_track": "記念日、誕生日、祝日、試験の重要な日付を追跡",
    // Alarm Extended
    "alarm_set": "毎日繰り返しのリマインダーアラーム設定", "alarm_daily": "毎日",
    "alarm_time_up": "時間です！",
    // Break Extended
    "break_30": "30 分", "break_45": "45 分", "break_60": "60 分",
    "break_90": "90 分", "break_120": "120 分",
    // Encoding Extended
    "encoding_to_label": "へ",
    // Notification Extended
    "notif_dnd_from": "から", "notif_dnd_to": "まで",
    // Shortcut Extended
    "shortcut_auth": "許可",
    // Wallpaper Extended 2
    "wallpaper_close": "壁紙を閉じる", "wallpaper_delete": "削除",
    "wallpaper_upload_fail": "アップロード失敗", "wallpaper_upload_success": "審査に提出済み",
    "wallpaper_set_private": "プライベート設定", "wallpaper_static": "静止画",
    "wallpaper_video": "動画", "wallpaper_image": "画像",
    "wallpaper_download": "ダウンロード", "wallpaper_loading": "読み込み中...",
    "wallpaper_username_required": "ユーザー名を先に設定してください",
    "wallpaper_pr_confirm": "削除しますか？PR が提交されます。",
    // Timer Extended
    "timer_skip": "スキップ", "timer_min": "分", "timer_sec": "秒", "timer_hour": "時間",
    // Monitor Extended
    "monitor_cores": "コア", "monitor_cycles": "サイクル",
    "monitor_idle": "アイドル", "monitor_capacity": "容量",
    "monitor_system": "システム", "monitor_user": "ユーザー",
    "monitor_app": "アプリ", "monitor_charging": "充電中", "monitor_remaining": "残り",
    "monitor_used": "使用済み", "monitor_compressed": "圧縮",
    // Date Format
    "date_format_weekday": "",
    // Misc Extended
    "close_panel": "閉じる", "collapse_overview": "折りたたむ", "skip": "スキップ",
    // Menu Bar
    "menu_hide_island": "アイランドを隠す", "menu_show_island": "アイランドを表示",
    "menu_collapse": "折りたたむ", "menu_check_for_updates": "アップデートを確認", "menu_settings": "設定", "menu_quit": "MacIsland を終了",
    // Update
    "update_available_title": "アップデートがあります",
    "update_available_message": "MacIsland %@ が利用可能です。アップデートしますか？",
    "update_download": "ダウンロード",
    "update_later": "後で通知",
    "update_up_to_date_title": "アップデートの確認",
    "update_up_to_date_message": "最新バージョンです！",
    "update_error_title": "アップデート確認失敗",
    // Service Errors
    "error_clipboard_link": "🔗 リンク検出",
    "error_weather_location": "位置情報の取得に失敗", "error_weather_fetch": "天気の取得に失敗", "error_weather_api_key": "先に QWeather API Key を設定してください",
    "error_lyrics_not_found": "歌詞が見つかりません",
    "error_ai_connection": "接続失敗", "error_ai_request": "API リクエスト失敗",
    "error_github_login": "先に GitHub にログインしてください", "error_github_token": "設定で先に GitHub にログインしてください",
    "error_github_size": "ファイルサイズが 100MB 制限を超えています", "error_github_video": "動画ファイルを読み込めません",
    "error_github_compress": "画像圧縮に失敗",
    "error_github_branch": "ブランチ作成に失敗",
    "error_github_branch_not_found": "ブランチが見つかりません。リポジトリに少なくとも1つのコミットを作成してください",
    "error_github_branch_info": "ブランチ情報を読み込めません",
    "error_github_file_create": "ファイル作成に失敗", "error_github_file_info": "ファイル情報を取得できません",
    "error_github_file_delete": "ファイル削除に失敗", "error_github_pr": "PR 作成に失敗",
    "error_github_repo": "コミュニティリポジトリは利用できません。後でもう一度お試しください",
    "error_github_permission": "権限不足（HTTP 403）。Token に repo 権限があることを確認してください",
    "error_github_http": "サーバーが HTTP を返しました", "error_github_network": "ネットワークエラー",
    // Timer Notifications
    "timer_notif_countdown": "⏱ カウントダウンリマインダー", "timer_notif_time_up": "⏱ カウントダウン",
    "timer_notif_focus_end": "🍅 集中完了", "timer_notif_break_end": "🍅 休憩終了",
    "timer_notif_rest": "休憩しましょう、完了",
    // AI System
    "ai_system_prompt": "あなたは MacIsland の AI アシスタントです。簡潔で、親切で、役に立つ回答をします。",
    // Default Values
    "default_alarm_label": "アラーム",
    // Navigation
    "nav_settings": "設定", "nav_tools": "ツール",
    // Stock
    "market_a_share": "A株", "market_us": "米国", "market_hk": "香港",
    "stock_title": "株式",
    "stock_search": "株式検索",
    "stock_search_action": "検索",
    "stock_watchlist": "ウォッチリスト",
    "stock_add": "追加",
    "stock_remove": "削除",
    "stock_price": "価格",
    "stock_change": "変動",
    "stock_no_data": "株式データなし",
    "stock_settings": "株式設定",
    "stock_auto_refresh": "自動更新",
    "stock_refresh_freq": "更新間隔",
    "stock_watchlist_manage": "ウォッチリスト管理",
    "stock_manage_watchlist": "ウォッチリスト管理",
    "stock_all_markets": "すべて",
    "stock_search_results": "検索結果",
    "stock_no_results": "一致する株式が見つかりません",
    "stock_added": "追加済み",
    "stock_search_above": "上記の検索ボックスにコードまたは銘柄名を入力",
    "stock_no_market_stocks": "この市場の銘柄はありません",

    // Date Format
    "date_format_cn": "yyyy年M月d日 EEEE",
    "date_format_short": "M/d（EEE）",
    // Setting Descriptions
    "desc_appearance_mode": "ダーク/ライト/システムテーマを切り替え。即時反映されます。",
    "desc_accent_color": "アクセントカラーをカスタマイズ。9色のプリセット、即時反映。",
    "desc_language": "表示言語を切り替え。中国語/英語/日本語に対応。",
    "desc_autostart": "ログイン後に MacIsland を自動起動します。",
    "desc_island_opacity": "アイランドの不透明度を調整（10%–100%）。",
    "desc_wallpaper_opacity": "アイランドとは独立した壁紙の不透明度。",
    "desc_widget_appearance": "ウィジェットのライト/ダークモードを設定します。アイランドに従うか独立して設定できます。",
    "desc_wallpaper_path": "壁紙キャッシュディレクトリを指定。空欄でデフォルト。",
    "desc_animation_speed": "展開/折りたたみアニメーションの遷移時間。",
    "desc_spring_animation": "バウンスするスプリングアニメーションを有効化。",
    "desc_link_detect": "リンクをコピー時にクイック通知を表示。",
    "desc_url_mode": "リンクとして認識する URL 形式を選択。",
    "desc_blacklist": "ブラックリストのドメインはリンク通知をトリガーしません。",
    "desc_dnd": "指定時間内にアイランド通知をミュート。",
    "desc_dnd_time": "通知オフの開始・終了時間を設定。",
    "desc_lyrics_source": "優先する歌詞データソース。",
    "desc_weather_api_key": "任意の QWeather API Key。空欄の場合は内蔵デフォルトを使用します。Key は UserDefaults ではなく Keychain に保存します。",
    "desc_weather_city": "都市名を指定。空欄で自動位置。",
    "desc_weather_location_id": "和風天気の都市 ID。手動都市と併用。",
    "desc_username": "コミュニティ壁紙アップロード時の著者名。",
    "desc_hotkey_bindings": "表示/再生制御のグローバルホットキーをカスタマイズ。",
]
