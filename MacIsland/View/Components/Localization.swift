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

// MARK: - Localized Strings (便捷访问)

/// 本地化字符串 — 调用 L10n.key 时自动从 LocalizationManager 读取
enum L10n {
    // Tab
    static var tabTodo: String { LocalizationManager.shared.localize("tab_todo") }
    static var tabMemo: String { LocalizationManager.shared.localize("tab_memo") }
    static var tabEvent: String { LocalizationManager.shared.localize("tab_event") }
    static var tabAlarm: String { LocalizationManager.shared.localize("tab_alarm") }
    static var tabBookmark: String { LocalizationManager.shared.localize("tab_bookmark") }
    static var tabAI: String { LocalizationManager.shared.localize("tab_ai") }
    static var tabSettings: String { LocalizationManager.shared.localize("tab_settings") }
    static var tabToolbox: String { LocalizationManager.shared.localize("tab_toolbox") }

    // Common
    static var add: String { LocalizationManager.shared.localize("common_add") }
    static var delete: String { LocalizationManager.shared.localize("common_delete") }
    static var save: String { LocalizationManager.shared.localize("common_save") }
    static var cancel: String { LocalizationManager.shared.localize("common_cancel") }
    static var confirm: String { LocalizationManager.shared.localize("common_confirm") }
    static var close: String { LocalizationManager.shared.localize("common_close") }
    static var open: String { LocalizationManager.shared.localize("common_open") }
    static var reset: String { LocalizationManager.shared.localize("common_reset") }
    static var copy: String { LocalizationManager.shared.localize("common_copy") }
    static var search: String { LocalizationManager.shared.localize("common_search") }
    static var noData: String { LocalizationManager.shared.localize("common_no_data") }

    // Todo
    static var todoTitle: String { LocalizationManager.shared.localize("todo_title") }
    static var todoPlaceholder: String { LocalizationManager.shared.localize("todo_placeholder") }
    static var todoSubtask: String { LocalizationManager.shared.localize("todo_subtask") }
    static var todoDescription: String { LocalizationManager.shared.localize("todo_description") }
    static var todoTrash: String { LocalizationManager.shared.localize("todo_trash") }
    static var todoEmpty: String { LocalizationManager.shared.localize("todo_empty") }
    static var todoComplete: String { LocalizationManager.shared.localize("todo_complete") }
    static var todoPending: String { LocalizationManager.shared.localize("todo_pending") }

    // Memo
    static var memoTitle: String { LocalizationManager.shared.localize("memo_title") }
    static var memoPlaceholder: String { LocalizationManager.shared.localize("memo_placeholder") }
    static var memoEmpty: String { LocalizationManager.shared.localize("memo_empty") }

    // Event
    static var eventTitle: String { LocalizationManager.shared.localize("event_title") }
    static var eventCountdown: String { LocalizationManager.shared.localize("event_countdown") }
    static var eventAnniversary: String { LocalizationManager.shared.localize("event_anniversary") }
    static var eventBirthday: String { LocalizationManager.shared.localize("event_birthday") }
    static var eventHoliday: String { LocalizationManager.shared.localize("event_holiday") }
    static var eventExam: String { LocalizationManager.shared.localize("event_exam") }

    // Alarm
    static var alarmTitle: String { LocalizationManager.shared.localize("alarm_title") }
    static var alarmLabel: String { LocalizationManager.shared.localize("alarm_label") }
    static var alarmRepeat: String { LocalizationManager.shared.localize("alarm_repeat") }

    // Bookmark
    static var bookmarkTitle: String { LocalizationManager.shared.localize("bookmark_title") }
    static var bookmarkName: String { LocalizationManager.shared.localize("bookmark_name") }
    static var bookmarkURL: String { LocalizationManager.shared.localize("bookmark_url") }
    static var bookmarkEmpty: String { LocalizationManager.shared.localize("bookmark_empty") }

    // Toolbox
    static var toolboxFileSearch: String { LocalizationManager.shared.localize("toolbox_file_search") }
    static var toolboxClipboard: String { LocalizationManager.shared.localize("toolbox_clipboard") }
    static var toolboxFileHash: String { LocalizationManager.shared.localize("toolbox_file_hash") }
    static var toolboxEncoding: String { LocalizationManager.shared.localize("toolbox_encoding") }
    static var toolboxTranslate: String { LocalizationManager.shared.localize("toolbox_translate") }
    static var toolboxMokugyo: String { LocalizationManager.shared.localize("toolbox_mokugyo") }
    static var toolboxBreakReminder: String { LocalizationManager.shared.localize("toolbox_break_reminder") }

    // Settings
    static var settingsGeneral: String { LocalizationManager.shared.localize("settings_general") }
    static var settingsShortcuts: String { LocalizationManager.shared.localize("settings_shortcuts") }
    static var settingsAbout: String { LocalizationManager.shared.localize("settings_about") }
    static var settingsAutostart: String { LocalizationManager.shared.localize("settings_autostart") }
    static var settingsOpacity: String { LocalizationManager.shared.localize("settings_opacity") }
    static var settingsAnimation: String { LocalizationManager.shared.localize("settings_animation") }
    static var settingsClipboard: String { LocalizationManager.shared.localize("settings_clipboard") }
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

// MARK: - Translation Dictionaries

/// 中文字符串
private let zhStrings: [String: String] = [
    "tab_todo": "待办", "tab_memo": "便签", "tab_event": "倒计时",
    "tab_alarm": "闹钟", "tab_bookmark": "书签", "tab_ai": "AI",
    "tab_settings": "设置", "tab_toolbox": "工具",
    "common_add": "添加", "common_delete": "删除", "common_save": "保存",
    "common_cancel": "取消", "common_confirm": "确认", "common_close": "关闭",
    "common_open": "打开", "common_reset": "重置", "common_copy": "复制",
    "common_search": "搜索", "common_no_data": "暂无数据",
    "todo_title": "待办事项", "todo_placeholder": "添加待办...",
    "todo_subtask": "子任务", "todo_description": "描述",
    "todo_trash": "回收站", "todo_empty": "管理你的任务，支持优先级和子任务",
    "todo_complete": "完成", "todo_pending": "待办",
    "memo_title": "便签", "memo_placeholder": "标题", "memo_empty": "快速记录想法和笔记",
    "event_title": "倒计时 & 纪念日", "event_countdown": "倒计时",
    "event_anniversary": "纪念日", "event_birthday": "生日",
    "event_holiday": "节日", "event_exam": "考试",
    "alarm_title": "闹钟", "alarm_label": "闹钟名称", "alarm_repeat": "重复",
    "bookmark_title": "URL 书签", "bookmark_name": "名称",
    "bookmark_url": "链接地址", "bookmark_empty": "收藏常用链接，快速访问",
    "toolbox_file_search": "文件搜索", "toolbox_clipboard": "剪贴板",
    "toolbox_file_hash": "文件哈希", "toolbox_encoding": "编码转换",
    "toolbox_translate": "翻译", "toolbox_mokugyo": "木鱼",
    "toolbox_break_reminder": "久坐提醒",
    "settings_general": "通用", "settings_shortcuts": "快捷键",
    "settings_about": "关于", "settings_autostart": "开机自启动",
    "settings_opacity": "灵动岛透明度", "settings_animation": "动画",
    "settings_clipboard": "剪贴板",
]

/// 英文字符串
private let enStrings: [String: String] = [
    "tab_todo": "Todo", "tab_memo": "Memo", "tab_event": "Events",
    "tab_alarm": "Alarm", "tab_bookmark": "Bookmarks", "tab_ai": "AI",
    "tab_settings": "Settings", "tab_toolbox": "Tools",
    "common_add": "Add", "common_delete": "Delete", "common_save": "Save",
    "common_cancel": "Cancel", "common_confirm": "Confirm", "common_close": "Close",
    "common_open": "Open", "common_reset": "Reset", "common_copy": "Copy",
    "common_search": "Search", "common_no_data": "No data",
    "todo_title": "Todo", "todo_placeholder": "Add todo...",
    "todo_subtask": "Subtask", "todo_description": "Description",
    "todo_trash": "Trash", "todo_empty": "Manage your tasks with priorities and subtasks",
    "todo_complete": "Done", "todo_pending": "Pending",
    "memo_title": "Memo", "memo_placeholder": "Title", "memo_empty": "Quick notes and ideas",
    "event_title": "Countdown & Anniversary", "event_countdown": "Countdown",
    "event_anniversary": "Anniversary", "event_birthday": "Birthday",
    "event_holiday": "Holiday", "event_exam": "Exam",
    "alarm_title": "Alarm", "alarm_label": "Label", "alarm_repeat": "Repeat",
    "bookmark_title": "URL Bookmarks", "bookmark_name": "Name",
    "bookmark_url": "URL", "bookmark_empty": "Save your favorite links",
    "toolbox_file_search": "File Search", "toolbox_clipboard": "Clipboard",
    "toolbox_file_hash": "File Hash", "toolbox_encoding": "Encoding",
    "toolbox_translate": "Translate", "toolbox_mokugyo": "Mokugyo",
    "toolbox_break_reminder": "Break Reminder",
    "settings_general": "General", "settings_shortcuts": "Shortcuts",
    "settings_about": "About", "settings_autostart": "Launch at Login",
    "settings_opacity": "Island Opacity", "settings_animation": "Animation",
    "settings_clipboard": "Clipboard",
]

/// 日文字符串
private let jaStrings: [String: String] = [
    "tab_todo": "やること", "tab_memo": "メモ", "tab_event": "イベント",
    "tab_alarm": "アラーム", "tab_bookmark": "ブックマーク", "tab_ai": "AI",
    "tab_settings": "設定", "tab_toolbox": "ツール",
    "common_add": "追加", "common_delete": "削除", "common_save": "保存",
    "common_cancel": "キャンセル", "common_confirm": "確認", "common_close": "閉じる",
    "common_open": "開く", "common_reset": "リセット", "common_copy": "コピー",
    "common_search": "検索", "common_no_data": "データなし",
    "todo_title": "やることリスト", "todo_placeholder": "タスクを追加...",
    "todo_subtask": "サブタスク", "todo_description": "説明",
    "todo_trash": "ゴミ箱", "todo_empty": "優先度とサブタスクでタスクを管理",
    "todo_complete": "完了", "todo_pending": "未完了",
    "memo_title": "メモ", "memo_placeholder": "タイトル", "memo_empty": "メモやアイデアを素早く記録",
    "event_title": "カウントダウン & 記念日", "event_countdown": "カウントダウン",
    "event_anniversary": "記念日", "event_birthday": "誕生日",
    "event_holiday": "祝日", "event_exam": "試験",
    "alarm_title": "アラーム", "alarm_label": "ラベル", "alarm_repeat": "繰り返し",
    "bookmark_title": "URL ブックマーク", "bookmark_name": "名前",
    "bookmark_url": "URL", "bookmark_empty": "お気に入りのリンクを保存",
    "toolbox_file_search": "ファイル検索", "toolbox_clipboard": "クリップボード",
    "toolbox_file_hash": "ファイルハッシュ", "toolbox_encoding": "エンコーディング",
    "toolbox_translate": "翻訳", "toolbox_mokugyo": "木魚",
    "toolbox_break_reminder": "休憩リマインダー",
    "settings_general": "一般", "settings_shortcuts": "ショートカット",
    "settings_about": "について", "settings_autostart": "ログイン時に起動",
    "settings_opacity": "アイランド透明度", "settings_animation": "アニメーション",
    "settings_clipboard": "クリップボード",
]
