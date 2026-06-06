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
            pendingItems: [
                TodoItem(id: "1", title: "Review PR", isCompleted: false),
                TodoItem(id: "2", title: "Update documentation", isCompleted: false),
                TodoItem(id: "3", title: "Fix bug #123", isCompleted: false),
                TodoItem(id: "4", title: "Deploy to staging", isCompleted: false),
            ]
        )
    }

    static func fromUserDefaults() -> TodoEntry {
        let d = WidgetConstants.sharedDefaults
        let totalCount = d.integer(forKey: "widget_todo_total")
        let completedCount = d.integer(forKey: "widget_todo_completed")

        // 读取待办列表（JSON 格式）
        var items: [TodoItem] = []
        if let data = d.data(forKey: "widget_todo_items"),
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
}

// MARK: - Todo Widget

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoTimelineProvider()) { entry in
            TodoWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
        VStack(spacing: 8) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text(entry.progressString)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Text("\(entry.pendingItems.count) pending")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：进度
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(entry.progress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }

                Text(entry.progressString)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)

            Divider()

            // 右侧：待办列表
            VStack(alignment: .leading, spacing: 6) {
                if entry.pendingItems.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All done!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                } else {
                    ForEach(entry.pendingItems.prefix(4)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(item.title)
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
