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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
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
        let lang = currentLanguage.rawValue
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return fallbackStrings[key] ?? key
        }
        return bundle.localizedString(forKey: key, value: fallbackStrings[key] ?? key, table: nil)
    }

    /// 后备字符串（中文）
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
