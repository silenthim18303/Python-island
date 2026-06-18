//
//  WidgetIntents.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/8.
//

import WidgetKit
import AppIntents

// MARK: - Todo Toggle Intent

/// 待办事项切换完成状态
struct TodoToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Todo"
    static var description = IntentDescription("Toggle the completion status of a todo item")

    @Parameter(title: "Todo ID")
    var todoId: String

    init() {}

    init(todoId: String) {
        self.todoId = todoId
    }

    func perform() async throws -> some IntentResult {
        // 读取当前待办数据
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.geminimortal.MacIsland")
        guard let fileURL = container?.appendingPathComponent("widget_data.json"),
              let data = try? Data(contentsOf: fileURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .result()
        }

        // 读取待办列表
        if let todoData = json["widget_todo_items"] as? [[String: Any]] {
            var items = todoData
            for i in 0..<items.count {
                if let id = items[i]["id"] as? String, id == todoId {
                    let current = items[i]["completed"] as? Bool ?? false
                    items[i]["completed"] = !current
                    break
                }
            }

            // 更新完成数
            let completedCount = items.filter { $0["completed"] as? Bool == true }.count
            json["widget_todo_items"] = items
            json["widget_todo_completed"] = completedCount

            // 写回文件
            if let newData = try? JSONSerialization.data(withJSONObject: json, options: []) {
                try? newData.write(to: fileURL, options: .atomic)
            }
        }

        // 刷新小组件
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")

        return .result()
    }
}

// MARK: - Timer Start/Stop Intent

/// 计时器开始/停止
struct TimerToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    static var description = IntentDescription("Start or stop the timer")

    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
        sharedDefaults.set(true, forKey: "widget_timer_toggle")
        sharedDefaults.synchronize()

        NotificationCenter.default.post(name: NSNotification.Name("WidgetTimerToggle"), object: nil)

        return .result()
    }
}

// MARK: - Timer Reset Intent

/// 计时器重置
struct TimerResetIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Timer"
    static var description = IntentDescription("Reset the timer")

    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
        sharedDefaults.set(true, forKey: "widget_timer_reset")
        sharedDefaults.synchronize()

        NotificationCenter.default.post(name: NSNotification.Name("WidgetTimerReset"), object: nil)

        return .result()
    }
}

// MARK: - Clipboard Copy Intent

/// 剪贴板复制
struct ClipboardCopyIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy to Clipboard"
    static var description = IntentDescription("Copy text to clipboard")

    @Parameter(title: "Text")
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        // 通过共享 UserDefaults 通知主应用
        let sharedDefaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
        sharedDefaults.set(text, forKey: "widget_clipboard_copy")
        sharedDefaults.synchronize()

        NotificationCenter.default.post(name: NSNotification.Name("WidgetClipboardCopy"), object: nil)

        return .result()
    }
}
