//
//  TodoWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Todo Timeline Provider

struct TodoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let entry = TodoEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Todo Entry

struct TodoEntry: TimelineEntry {
    let date: Date
    let totalCount: Int
    let completedCount: Int
    let updatedAt: Date?
    let pendingItems: [TodoItem]

    struct TodoItem: Identifiable {
        let id: String
        let title: String
        let isCompleted: Bool
    }

    static var placeholder: TodoEntry {
        TodoEntry(
            date: Date(),
            totalCount: 8,
            completedCount: 3,
            updatedAt: Date(),
            pendingItems: [
                TodoItem(id: "1", title: "整理今日任务", isCompleted: false),
                TodoItem(id: "2", title: "更新文档", isCompleted: false),
                TodoItem(id: "3", title: "修复反馈问题", isCompleted: false),
                TodoItem(id: "4", title: "发布测试包", isCompleted: false),
            ]
        )
    }

    static func fromUserDefaults() -> TodoEntry {
        let totalCount = WidgetConstants.int("widget_todo_total")
        let completedCount = WidgetConstants.int("widget_todo_completed")
        let ts = WidgetConstants.double("widget_todo_updated_at")

        var items: [TodoItem] = []
        if let data = WidgetConstants.data("widget_todo_items"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in json {
                if let id = dict["id"] as? String,
                   let title = dict["title"] as? String,
                   let completed = dict["completed"] as? Bool {
                    items.append(TodoItem(id: id, title: title, isCompleted: completed))
                }
            }
        }

        return TodoEntry(
            date: Date(),
            totalCount: totalCount,
            completedCount: completedCount,
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            pendingItems: items.filter { !$0.isCompleted }
        )
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var progressString: String {
        "\(completedCount)/\(totalCount)"
    }

    var pendingCount: Int { max(totalCount - completedCount, 0) }
    var updateString: String { WidgetFormat.relativeTime(updatedAt) }
}

// MARK: - Todo Widget

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoTimelineProvider()) { entry in
            TodoWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName("待办事项")
        .description("显示待办列表和完成进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Todo Widget View

struct TodoWidgetView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(icon: "checklist", title: "待办", trailing: entry.updateString, color: .green)

            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 4)
                        .frame(width: 46, height: 46)

                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))

                    Text(entry.progressString)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("待处理")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            WidgetProgressBar(value: entry.progress, color: .green, height: 3)
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 9) {
            WidgetHeader(icon: "checklist", title: "待办事项", trailing: entry.updateString, color: .green)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("待处理")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)

                    WidgetProgressBar(value: entry.progress, color: .green, height: 4)

                    Text("完成 \(entry.progressString)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 74, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 5) {
                    if entry.pendingItems.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(entry.totalCount == 0 ? "还没有待办" : "全部完成")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    } else {
                        ForEach(entry.pendingItems.prefix(4)) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "circle")
                                    .font(.system(size: 7))
                                    .foregroundColor(.green.opacity(0.8))
                                    .frame(width: 10)
                                Text(item.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}
