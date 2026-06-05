//
//  Localization.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

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

// MARK: - Localized Strings

/// 本地化字符串 — 通过 key 查找当前语言的翻译
enum L10n {
    /// 当前语言（UserDefaults 持久化）
    static var currentLanguage: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
            return AppLanguage(rawValue: raw) ?? .zh
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
        }
    }

    // MARK: - Tab Names

    static let tabTodo = localize("tab_todo")
    static let tabMemo = localize("tab_memo")
    static let tabEvent = localize("tab_event")
    static let tabAlarm = localize("tab_alarm")
    static let tabBookmark = localize("tab_bookmark")
    static let tabAI = localize("tab_ai")
    static let tabSettings = localize("tab_settings")
    static let tabToolbox = localize("tab_toolbox")

    // MARK: - Common

    static let add = localize("common_add")
    static let delete = localize("common_delete")
    static let save = localize("common_save")
    static let cancel = localize("common_cancel")
    static let confirm = localize("common_confirm")
    static let close = localize("common_close")
    static let open = localize("common_open")
    static let reset = localize("common_reset")
    static let copy = localize("common_copy")
    static let search = localize("common_search")
    static let noData = localize("common_no_data")

    // MARK: - Todo

    static let todoTitle = localize("todo_title")
    static let todoPlaceholder = localize("todo_placeholder")
    static let todoSubtask = localize("todo_subtask")
    static let todoDescription = localize("todo_description")
    static let todoTrash = localize("todo_trash")
    static let todoEmpty = localize("todo_empty")
    static let todoComplete = localize("todo_complete")
    static let todoPending = localize("todo_pending")

    // MARK: - Memo

    static let memoTitle = localize("memo_title")
    static let memoPlaceholder = localize("memo_placeholder")
    static let memoEmpty = localize("memo_empty")

    // MARK: - Event

    static let eventTitle = localize("event_title")
    static let eventCountdown = localize("event_countdown")
    static let eventAnniversary = localize("event_anniversary")
    static let eventBirthday = localize("event_birthday")
    static let eventHoliday = localize("event_holiday")
    static let eventExam = localize("event_exam")

    // MARK: - Alarm

    static let alarmTitle = localize("alarm_title")
    static let alarmLabel = localize("alarm_label")
    static let alarmRepeat = localize("alarm_repeat")

    // MARK: - Bookmark

    static let bookmarkTitle = localize("bookmark_title")
    static let bookmarkName = localize("bookmark_name")
    static let bookmarkURL = localize("bookmark_url")
    static let bookmarkEmpty = localize("bookmark_empty")

    // MARK: - Toolbox

    static let toolboxFileSearch = localize("toolbox_file_search")
    static let toolboxClipboard = localize("toolbox_clipboard")
    static let toolboxFileHash = localize("toolbox_file_hash")
    static let toolboxEncoding = localize("toolbox_encoding")
    static let toolboxTranslate = localize("toolbox_translate")
    static let toolboxMokugyo = localize("toolbox_mokugyo")
    static let toolboxBreakReminder = localize("toolbox_break_reminder")

    // MARK: - Settings

    static let settingsGeneral = localize("settings_general")
    static let settingsShortcuts = localize("settings_shortcuts")
    static let settingsAbout = localize("settings_about")
    static let settingsAutostart = localize("settings_autostart")
    static let settingsOpacity = localize("settings_opacity")
    static let settingsAnimation = localize("settings_animation")
    static let settingsClipboard = localize("settings_clipboard")

    // MARK: - Private

    private static func localize(_ key: String) -> String {
        let lang = currentLanguage
        // 优先从 lproj bundle 取（如果有的话）
        if let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        // 回退到内置字典
        switch lang {
        case .ja: return jaStrings[key] ?? fallbackStrings[key] ?? key
        case .en: return enStrings[key] ?? fallbackStrings[key] ?? key
        case .zh: return fallbackStrings[key] ?? key
        }
    }

    /// 英文字符串
    private static let enStrings: [String: String] = [
        // Tab
        "tab_todo": "Todo", "tab_memo": "Memo", "tab_event": "Events",
        "tab_alarm": "Alarm", "tab_bookmark": "Bookmarks", "tab_ai": "AI",
        "tab_settings": "Settings", "tab_toolbox": "Tools",
        // Common
        "common_add": "Add", "common_delete": "Delete", "common_save": "Save",
        "common_cancel": "Cancel", "common_confirm": "Confirm", "common_close": "Close",
        "common_open": "Open", "common_reset": "Reset", "common_copy": "Copy",
        "common_search": "Search", "common_no_data": "No data",
        // Todo
        "todo_title": "Todo", "todo_placeholder": "Add todo...",
        "todo_subtask": "Subtask", "todo_description": "Description",
        "todo_trash": "Trash", "todo_empty": "Manage your tasks with priorities and subtasks",
        "todo_complete": "Done", "todo_pending": "Pending",
        // Memo
        "memo_title": "Memo", "memo_placeholder": "Title", "memo_empty": "Quick notes and ideas",
        // Event
        "event_title": "Countdown & Anniversary", "event_countdown": "Countdown",
        "event_anniversary": "Anniversary", "event_birthday": "Birthday",
        "event_holiday": "Holiday", "event_exam": "Exam",
        // Alarm
        "alarm_title": "Alarm", "alarm_label": "Label", "alarm_repeat": "Repeat",
        // Bookmark
        "bookmark_title": "URL Bookmarks", "bookmark_name": "Name",
        "bookmark_url": "URL", "bookmark_empty": "Save your favorite links",
        // Toolbox
        "toolbox_file_search": "File Search", "toolbox_clipboard": "Clipboard",
        "toolbox_file_hash": "File Hash", "toolbox_encoding": "Encoding",
        "toolbox_translate": "Translate", "toolbox_mokugyo": "Mokugyo",
        "toolbox_break_reminder": "Break Reminder",
        // Settings
        "settings_general": "General", "settings_shortcuts": "Shortcuts",
        "settings_about": "About", "settings_autostart": "Launch at Login",
        "settings_opacity": "Island Opacity", "settings_animation": "Animation",
        "settings_clipboard": "Clipboard",
    ]

    /// 日文字符串
    private static let jaStrings: [String: String] = [
        // Tab
        "tab_todo": "やること", "tab_memo": "メモ", "tab_event": "イベント",
        "tab_alarm": "アラーム", "tab_bookmark": "ブックマーク", "tab_ai": "AI",
        "tab_settings": "設定", "tab_toolbox": "ツール",
        // Common
        "common_add": "追加", "common_delete": "削除", "common_save": "保存",
        "common_cancel": "キャンセル", "common_confirm": "確認", "common_close": "閉じる",
        "common_open": "開く", "common_reset": "リセット", "common_copy": "コピー",
        "common_search": "検索", "common_no_data": "データなし",
        // Todo
        "todo_title": "やることリスト", "todo_placeholder": "タスクを追加...",
        "todo_subtask": "サブタスク", "todo_description": "説明",
        "todo_trash": "ゴミ箱", "todo_empty": "優先度とサブタスクでタスクを管理",
        "todo_complete": "完了", "todo_pending": "未完了",
        // Memo
        "memo_title": "メモ", "memo_placeholder": "タイトル", "memo_empty": "メモやアイデアを素早く記録",
        // Event
        "event_title": "カウントダウン & 記念日", "event_countdown": "カウントダウン",
        "event_anniversary": "記念日", "event_birthday": "誕生日",
        "event_holiday": "祝日", "event_exam": "試験",
        // Alarm
        "alarm_title": "アラーム", "alarm_label": "ラベル", "alarm_repeat": "繰り返し",
        // Bookmark
        "bookmark_title": "URL ブックマーク", "bookmark_name": "名前",
        "bookmark_url": "URL", "bookmark_empty": "お気に入りのリンクを保存",
        // Toolbox
        "toolbox_file_search": "ファイル検索", "toolbox_clipboard": "クリップボード",
        "toolbox_file_hash": "ファイルハッシュ", "toolbox_encoding": "エンコーディング",
        "toolbox_translate": "翻訳", "toolbox_mokugyo": "木魚",
        "toolbox_break_reminder": "休憩リマインダー",
        // Settings
        "settings_general": "一般", "settings_shortcuts": "ショートカット",
        "settings_about": "について", "settings_autostart": "ログイン時に起動",
        "settings_opacity": "アイランド透明度", "settings_animation": "アニメーション",
        "settings_clipboard": "クリップボード",
    ]

    /// 中文后备字符串
    private static let fallbackStrings: [String: String] = [
        // Tab
        "tab_todo": "待办",
        "tab_memo": "便签",
        "tab_event": "倒计时",
        "tab_alarm": "闹钟",
        "tab_bookmark": "书签",
        "tab_ai": "AI",
        "tab_settings": "设置",
        "tab_toolbox": "工具",

        // Common
        "common_add": "添加",
        "common_delete": "删除",
        "common_save": "保存",
        "common_cancel": "取消",
        "common_confirm": "确认",
        "common_close": "关闭",
        "common_open": "打开",
        "common_reset": "重置",
        "common_copy": "复制",
        "common_search": "搜索",
        "common_no_data": "暂无数据",

        // Todo
        "todo_title": "待办事项",
        "todo_placeholder": "添加待办...",
        "todo_subtask": "子任务",
        "todo_description": "描述",
        "todo_trash": "回收站",
        "todo_empty": "管理你的任务，支持优先级和子任务",
        "todo_complete": "完成",
        "todo_pending": "待办",

        // Memo
        "memo_title": "便签",
        "memo_placeholder": "标题",
        "memo_empty": "快速记录想法和笔记",

        // Event
        "event_title": "倒计时 & 纪念日",
        "event_countdown": "倒计时",
        "event_anniversary": "纪念日",
        "event_birthday": "生日",
        "event_holiday": "节日",
        "event_exam": "考试",

        // Alarm
        "alarm_title": "闹钟",
        "alarm_label": "闹钟名称",
        "alarm_repeat": "重复",

        // Bookmark
        "bookmark_title": "URL 书签",
        "bookmark_name": "名称",
        "bookmark_url": "链接地址",
        "bookmark_empty": "收藏常用链接，快速访问",

        // Toolbox
        "toolbox_file_search": "文件搜索",
        "toolbox_clipboard": "剪贴板",
        "toolbox_file_hash": "文件哈希",
        "toolbox_encoding": "编码转换",
        "toolbox_translate": "翻译",
        "toolbox_mokugyo": "木鱼",
        "toolbox_break_reminder": "久坐提醒",

        // Settings
        "settings_general": "通用",
        "settings_shortcuts": "快捷键",
        "settings_about": "关于",
        "settings_autostart": "开机自启动",
        "settings_opacity": "灵动岛透明度",
        "settings_animation": "动画",
        "settings_clipboard": "剪贴板",
    ]
}

// MARK: - Language Settings View

/// 语言设置视图
struct LanguageSettingsView: View {
    @State private var currentLang = L10n.currentLanguage

    var body: some View {
        Picker("语言", selection: $currentLang) {
            ForEach(AppLanguage.allCases) { lang in
                Text(lang.displayName).tag(lang)
            }
        }
        .onChange(of: currentLang) { _, newValue in
            L10n.currentLanguage = newValue
        }
    }
}
