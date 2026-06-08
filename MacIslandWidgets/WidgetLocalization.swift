//
//  WidgetLocalization.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation

/// 小组件本地化管理器
enum WidgetL10n {
    /// 当前语言
    private static var currentLanguage: String {
        // 从共享 UserDefaults 读取语言设置
        let sharedDefaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
        return sharedDefaults.string(forKey: "appLanguage") ?? "zh"
    }

    /// 获取本地化字符串
    static func t(_ key: String) -> String {
        let lang = currentLanguage
        switch lang {
        case "en":
            return enStrings[key] ?? zhStrings[key] ?? key
        case "ja":
            return jaStrings[key] ?? zhStrings[key] ?? key
        default:
            return zhStrings[key] ?? key
        }
    }

    // MARK: - 天气小组件

    static var weatherDisplayName: String { t("widget_weather_display_name") }
    static var weatherDescription: String { t("widget_weather_description") }
    static var weatherSyncHint: String { t("widget_weather_sync_hint") }
    static var weatherOpenHint: String { t("widget_weather_open_hint") }
    static var weatherHighLow: String { t("widget_weather_high_low") }
    static var weatherHumidity: String { t("widget_weather_humidity") }
    static var weatherWindSpeed: String { t("widget_weather_wind_speed") }
    static var weatherCurrentLocation: String { t("widget_weather_current_location") }

    // MARK: - 音乐小组件

    static var musicDisplayName: String { t("widget_music_display_name") }
    static var musicDescription: String { t("widget_music_description") }
    static var musicTitle: String { t("widget_music_title") }
    static var musicNoPlayback: String { t("widget_music_no_playback") }
    static var musicNoContent: String { t("widget_music_no_content") }
    static var musicPlaying: String { t("widget_music_playing") }
    static var musicPaused: String { t("widget_music_paused") }
    static var musicUnknownArtist: String { t("widget_music_unknown_artist") }
    static var musicNowPlaying: String { t("widget_music_now_playing") }

    // MARK: - 计时器小组件

    static var timerDisplayName: String { t("widget_timer_display_name") }
    static var timerDescription: String { t("widget_timer_description") }
    static var timerPomodoro: String { t("widget_timer_pomodoro") }
    static var timerCountdown: String { t("widget_timer_countdown") }
    static var timerIdle: String { t("widget_timer_idle") }
    static var timerNoTask: String { t("widget_timer_no_task") }
    static var timerNoTaskDetail: String { t("widget_timer_no_task_detail") }
    static var timerStatus: String { t("widget_timer_status") }
    static var timerTotalTime: String { t("widget_timer_total_time") }
    static var timerCompleted: String { t("widget_timer_completed") }
    static var timerRemaining: String { t("widget_timer_remaining") }
    static var timerPhase: String { t("widget_timer_phase") }
    static var timerRunning: String { t("widget_timer_running") }
    static var timerPaused: String { t("widget_timer_paused") }
    static var timerCompletedStatus: String { t("widget_timer_completed_status") }
    static var timerIdleStatus: String { t("widget_timer_idle_status") }
    static var timerPomodoroCompleted: String { t("widget_timer_pomodoro_completed") }

    // MARK: - 系统监控小组件

    static var monitorDisplayName: String { t("widget_monitor_display_name") }
    static var monitorDescription: String { t("widget_monitor_description") }
    static var monitorSystem: String { t("widget_monitor_system") }
    static var monitorSyncHint: String { t("widget_monitor_sync_hint") }
    static var monitorOpenHint: String { t("widget_monitor_open_hint") }
    static var monitorCPU: String { t("widget_monitor_cpu") }
    static var monitorMemory: String { t("widget_monitor_memory") }
    static var monitorDisk: String { t("widget_monitor_disk") }
    static var monitorBattery: String { t("widget_monitor_battery") }
    static var monitorNetwork: String { t("widget_monitor_network") }
    static var monitorDownload: String { t("widget_monitor_download") }
    static var monitorUpload: String { t("widget_monitor_upload") }
    static var monitorOffline: String { t("widget_monitor_offline") }
    static var monitorOnline: String { t("widget_monitor_online") }
    static var monitorCharging: String { t("widget_monitor_charging") }
    static var monitorDischarging: String { t("widget_monitor_discharging") }

    // MARK: - 待办小组件

    static var todoDisplayName: String { t("widget_todo_display_name") }
    static var todoDescription: String { t("widget_todo_description") }
    static var todoSyncHint: String { t("widget_todo_sync_hint") }
    static var todoPending: String { t("widget_todo_pending") }
    static var todoAllDone: String { t("widget_todo_all_done") }

    // MARK: - 剪贴板小组件

    static var clipboardDisplayName: String { t("widget_clipboard_display_name") }
    static var clipboardDescription: String { t("widget_clipboard_description") }
    static var clipboardTitle: String { t("widget_clipboard_title") }
    static var clipboardHistory: String { t("widget_clipboard_history") }
    static var clipboardNoItems: String { t("widget_clipboard_no_items") }
    static var clipboardNoContent: String { t("widget_clipboard_no_content") }
    static var clipboardLink: String { t("widget_clipboard_link") }
    static var clipboardText: String { t("widget_clipboard_text") }
    static var clipboardItems: String { t("widget_clipboard_items") }
    static var clipboardJustNow: String { t("widget_clipboard_just_now") }
    static var clipboardMinutesAgo: String { t("widget_clipboard_minutes_ago") }
    static var clipboardHoursAgo: String { t("widget_clipboard_hours_ago") }

    // MARK: - 倒数日小组件

    static var eventDisplayName: String { t("widget_event_display_name") }
    static var eventDescription: String { t("widget_event_description") }
    static var eventSyncHint: String { t("widget_event_sync_hint") }
    static var eventNoEvents: String { t("widget_event_no_events") }
    static var eventToday: String { t("widget_event_today") }
    static var eventDaysAgo: String { t("widget_event_days_ago") }
    static var eventDays: String { t("widget_event_days") }
    static var eventMore: String { t("widget_event_more") }
    static var eventEvents: String { t("widget_event_events") }

    // MARK: - 通用

    static var justNow: String { t("widget_just_now") }
    static var minutesAgo: String { t("widget_minutes_ago") }
    static var hoursAgo: String { t("widget_hours_ago") }
    static var daysAgo: String { t("widget_days_ago") }
    static var count: String { t("widget_count") }

    // MARK: - 中文

    private static let zhStrings: [String: String] = [
        // 天气
        "widget_weather_display_name": "天气",
        "widget_weather_description": "显示当前天气信息",
        "widget_weather_sync_hint": "天气尚未同步",
        "widget_weather_open_hint": "打开 MacIsland 同步天气",
        "widget_weather_high_low": "高低温",
        "widget_weather_humidity": "湿度",
        "widget_weather_wind_speed": "风速",
        "widget_weather_current_location": "当前位置",

        // 音乐
        "widget_music_display_name": "音乐",
        "widget_music_description": "显示当前播放的音乐",
        "widget_music_title": "音乐",
        "widget_music_no_playback": "暂无播放",
        "widget_music_no_content": "暂无播放内容",
        "widget_music_playing": "播放中",
        "widget_music_paused": "已暂停",
        "widget_music_unknown_artist": "未知艺人",
        "widget_music_now_playing": "正在播放",

        // 计时器
        "widget_timer_display_name": "计时器",
        "widget_timer_description": "番茄钟和倒计时",
        "widget_timer_pomodoro": "番茄钟",
        "widget_timer_countdown": "倒计时",
        "widget_timer_idle": "计时器",
        "widget_timer_no_task": "暂无计时任务",
        "widget_timer_no_task_detail": "番茄钟和倒计时空闲中",
        "widget_timer_status": "状态",
        "widget_timer_total_time": "总时长",
        "widget_timer_completed": "完成",
        "widget_timer_remaining": "剩余",
        "widget_timer_phase": "当前阶段",
        "widget_timer_running": "运行中",
        "widget_timer_paused": "已暂停",
        "widget_timer_completed_status": "已完成",
        "widget_timer_idle_status": "空闲",
        "widget_timer_pomodoro_completed": "个番茄完成",

        // 系统监控
        "widget_monitor_display_name": "系统监控",
        "widget_monitor_description": "CPU、内存、磁盘、电池、网络状态",
        "widget_monitor_system": "系统",
        "widget_monitor_sync_hint": "系统数据未同步",
        "widget_monitor_open_hint": "打开 MacIsland 同步系统状态",
        "widget_monitor_cpu": "CPU",
        "widget_monitor_memory": "内存",
        "widget_monitor_disk": "磁盘",
        "widget_monitor_battery": "电池",
        "widget_monitor_network": "网络",
        "widget_monitor_download": "下载",
        "widget_monitor_upload": "上传",
        "widget_monitor_offline": "离线",
        "widget_monitor_online": "在线",
        "widget_monitor_charging": "充电中",
        "widget_monitor_discharging": "放电中",

        // 待办
        "widget_todo_display_name": "待办事项",
        "widget_todo_description": "显示待办列表和完成进度",
        "widget_todo_sync_hint": "待办数据未同步",
        "widget_todo_pending": "个待办",
        "widget_todo_all_done": "全部完成",

        // 剪贴板
        "widget_clipboard_display_name": "剪贴板",
        "widget_clipboard_description": "最近复制的内容",
        "widget_clipboard_title": "剪贴板",
        "widget_clipboard_history": "剪贴板历史",
        "widget_clipboard_no_items": "暂无剪贴板记录",
        "widget_clipboard_no_content": "暂无复制内容",
        "widget_clipboard_link": "链接",
        "widget_clipboard_text": "文本",
        "widget_clipboard_items": "条",
        "widget_clipboard_just_now": "刚刚",
        "widget_clipboard_minutes_ago": "分",
        "widget_clipboard_hours_ago": "时",

        // 倒数日
        "widget_event_display_name": "倒数日",
        "widget_event_description": "即将到来的事件和倒计时",
        "widget_event_sync_hint": "倒数日数据未同步",
        "widget_event_no_events": "暂无事件",
        "widget_event_today": "今天！",
        "widget_event_days_ago": "天前",
        "widget_event_days": "天",
        "widget_event_more": "更多",
        "widget_event_events": "个事件",

        // 通用
        "widget_just_now": "刚刚",
        "widget_minutes_ago": "分钟前",
        "widget_hours_ago": "小时前",
        "widget_days_ago": "天前",
        "widget_count": "个",
    ]

    // MARK: - 英文

    private static let enStrings: [String: String] = [
        // Weather
        "widget_weather_display_name": "Weather",
        "widget_weather_description": "Show current weather information",
        "widget_weather_sync_hint": "Weather not synced",
        "widget_weather_open_hint": "Open MacIsland to sync weather",
        "widget_weather_high_low": "High/Low",
        "widget_weather_humidity": "Humidity",
        "widget_weather_wind_speed": "Wind",
        "widget_weather_current_location": "Current Location",

        // Music
        "widget_music_display_name": "Music",
        "widget_music_description": "Show currently playing music",
        "widget_music_title": "Music",
        "widget_music_no_playback": "No Playback",
        "widget_music_no_content": "No music playing",
        "widget_music_playing": "Playing",
        "widget_music_paused": "Paused",
        "widget_music_unknown_artist": "Unknown Artist",
        "widget_music_now_playing": "Now Playing",

        // Timer
        "widget_timer_display_name": "Timer",
        "widget_timer_description": "Pomodoro and countdown",
        "widget_timer_pomodoro": "Pomodoro",
        "widget_timer_countdown": "Countdown",
        "widget_timer_idle": "Timer",
        "widget_timer_no_task": "No active timer",
        "widget_timer_no_task_detail": "Pomodoro and countdown idle",
        "widget_timer_status": "Status",
        "widget_timer_total_time": "Total",
        "widget_timer_completed": "Done",
        "widget_timer_remaining": "Remaining",
        "widget_timer_phase": "Phase",
        "widget_timer_running": "Running",
        "widget_timer_paused": "Paused",
        "widget_timer_completed_status": "Completed",
        "widget_timer_idle_status": "Idle",
        "widget_timer_pomodoro_completed": "pomodoros done",

        // System Monitor
        "widget_monitor_display_name": "System Monitor",
        "widget_monitor_description": "CPU, Memory, Disk, Battery, Network",
        "widget_monitor_system": "System",
        "widget_monitor_sync_hint": "System data not synced",
        "widget_monitor_open_hint": "Open MacIsland to sync system status",
        "widget_monitor_cpu": "CPU",
        "widget_monitor_memory": "Memory",
        "widget_monitor_disk": "Disk",
        "widget_monitor_battery": "Battery",
        "widget_monitor_network": "Network",
        "widget_monitor_download": "Download",
        "widget_monitor_upload": "Upload",
        "widget_monitor_offline": "Offline",
        "widget_monitor_online": "Online",
        "widget_monitor_charging": "Charging",
        "widget_monitor_discharging": "Discharging",

        // Todo
        "widget_todo_display_name": "Todo",
        "widget_todo_description": "Show todo list and progress",
        "widget_todo_sync_hint": "Todo data not synced",
        "widget_todo_pending": "pending",
        "widget_todo_all_done": "All done!",

        // Clipboard
        "widget_clipboard_display_name": "Clipboard",
        "widget_clipboard_description": "Recently copied content",
        "widget_clipboard_title": "Clipboard",
        "widget_clipboard_history": "Clipboard History",
        "widget_clipboard_no_items": "No clipboard items",
        "widget_clipboard_no_content": "No copied content",
        "widget_clipboard_link": "Link",
        "widget_clipboard_text": "Text",
        "widget_clipboard_items": "items",
        "widget_clipboard_just_now": "now",
        "widget_clipboard_minutes_ago": "m",
        "widget_clipboard_hours_ago": "h",

        // Events
        "widget_event_display_name": "Events",
        "widget_event_description": "Upcoming events and countdowns",
        "widget_event_sync_hint": "Events data not synced",
        "widget_event_no_events": "No events",
        "widget_event_today": "Today!",
        "widget_event_days_ago": " days ago",
        "widget_event_days": " days",
        "widget_event_more": "more",
        "widget_event_events": "events",

        // Common
        "widget_just_now": "just now",
        "widget_minutes_ago": " minutes ago",
        "widget_hours_ago": " hours ago",
        "widget_days_ago": " days ago",
        "widget_count": "",
    ]

    // MARK: - 日文

    private static let jaStrings: [String: String] = [
        // 天気
        "widget_weather_display_name": "天気",
        "widget_weather_description": "現在の天気情報を表示",
        "widget_weather_sync_hint": "天気が同期されていません",
        "widget_weather_open_hint": "MacIslandを開いて天気を同期",
        "widget_weather_high_low": "最高/最低",
        "widget_weather_humidity": "湿度",
        "widget_weather_wind_speed": "風速",
        "widget_weather_current_location": "現在地",

        // 音楽
        "widget_music_display_name": "音楽",
        "widget_music_description": "再生中の音楽を表示",
        "widget_music_title": "音楽",
        "widget_music_no_playback": "再生なし",
        "widget_music_no_content": "再生中の音楽がありません",
        "widget_music_playing": "再生中",
        "widget_music_paused": "一時停止",
        "widget_music_unknown_artist": "不明なアーティスト",
        "widget_music_now_playing": "再生中",

        // タイマー
        "widget_timer_display_name": "タイマー",
        "widget_timer_description": "ポモドーロとカウントダウン",
        "widget_timer_pomodoro": "ポモドーロ",
        "widget_timer_countdown": "カウントダウン",
        "widget_timer_idle": "タイマー",
        "widget_timer_no_task": "タスクなし",
        "widget_timer_no_task_detail": "ポモドーロとカウントダウンがアイドル中",
        "widget_timer_status": "ステータス",
        "widget_timer_total_time": "合計時間",
        "widget_timer_completed": "完了",
        "widget_timer_remaining": "残り",
        "widget_timer_phase": "フェーズ",
        "widget_timer_running": "実行中",
        "widget_timer_paused": "一時停止",
        "widget_timer_completed_status": "完了",
        "widget_timer_idle_status": "アイドル",
        "widget_timer_pomodoro_completed": "ポモドーロ完了",

        // システムモニター
        "widget_monitor_display_name": "システムモニター",
        "widget_monitor_description": "CPU、メモリ、ディスク、バッテリー、ネットワーク",
        "widget_monitor_system": "システム",
        "widget_monitor_sync_hint": "システムデータが同期されていません",
        "widget_monitor_open_hint": "MacIslandを開いてシステム状態を同期",
        "widget_monitor_cpu": "CPU",
        "widget_monitor_memory": "メモリ",
        "widget_monitor_disk": "ディスク",
        "widget_monitor_battery": "バッテリー",
        "widget_monitor_network": "ネットワーク",
        "widget_monitor_download": "ダウンロード",
        "widget_monitor_upload": "アップロード",
        "widget_monitor_offline": "オフライン",
        "widget_monitor_online": "オンライン",
        "widget_monitor_charging": "充電中",
        "widget_monitor_discharging": "放電中",

        // TODO
        "widget_todo_display_name": "TODO",
        "widget_todo_description": "TODOリストと進捗を表示",
        "widget_todo_sync_hint": "TODOデータが同期されていません",
        "widget_todo_pending": "件のタスク",
        "widget_todo_all_done": "すべて完了！",

        // クリップボード
        "widget_clipboard_display_name": "クリップボード",
        "widget_clipboard_description": "最近コピーした内容",
        "widget_clipboard_title": "クリップボード",
        "widget_clipboard_history": "クリップボード履歴",
        "widget_clipboard_no_items": "クリップボードアイテムなし",
        "widget_clipboard_no_content": "コピーされた内容がありません",
        "widget_clipboard_link": "リンク",
        "widget_clipboard_text": "テキスト",
        "widget_clipboard_items": "件",
        "widget_clipboard_just_now": "たった今",
        "widget_clipboard_minutes_ago": "分前",
        "widget_clipboard_hours_ago": "時間前",

        // イベント
        "widget_event_display_name": "カウントダウン",
        "widget_event_description": " upcoming events and countdowns",
        "widget_event_sync_hint": "イベントデータが同期されていません",
        "widget_event_no_events": "イベントなし",
        "widget_event_today": "今日！",
        "widget_event_days_ago": "日前",
        "widget_event_days": "日",
        "widget_event_more": "他",
        "widget_event_events": "件のイベント",

        // 共通
        "widget_just_now": "たった今",
        "widget_minutes_ago": "分前",
        "widget_hours_ago": "時間前",
        "widget_days_ago": "日前",
        "widget_count": "件",
    ]
}
