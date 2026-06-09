//
//  ClipboardWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Clipboard Timeline Provider

struct ClipboardTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClipboardEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClipboardEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClipboardEntry>) -> Void) {
        let entry = ClipboardEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 10, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Clipboard Entry

struct ClipboardEntry: TimelineEntry {
    let date: Date
    let updatedAt: Date?
    let recentItems: [ClipboardItem]

    struct ClipboardItem: Identifiable {
        let id: String
        let text: String
        let timestamp: Date
        var isURL: Bool { text.hasPrefix("http://") || text.hasPrefix("https://") }
    }

    static var placeholder: ClipboardEntry {
        ClipboardEntry(
            date: Date(),
            updatedAt: Date(),
            recentItems: [
                ClipboardItem(id: "1", text: "https://github.com/MacIsland", timestamp: Date()),
                ClipboardItem(id: "2", text: "今天要整理的任务清单", timestamp: Date().addingTimeInterval(-60)),
                ClipboardItem(id: "3", text: "let x = 42", timestamp: Date().addingTimeInterval(-120)),
            ]
        )
    }

    static func fromUserDefaults() -> ClipboardEntry {
        let ts = WidgetConstants.double("widget_clipboard_updated_at")
        var items: [ClipboardItem] = []

        if let data = WidgetConstants.data("widget_clipboard_items"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in json {
                if let id = dict["id"] as? String,
                   let text = dict["text"] as? String,
                   let timestamp = dict["timestamp"] as? TimeInterval {
                    items.append(ClipboardItem(id: id, text: text, timestamp: Date(timeIntervalSince1970: timestamp)))
                }
            }
        }

        return ClipboardEntry(
            date: Date(),
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            recentItems: items
        )
    }

    var updateString: String { WidgetFormat.relativeTime(updatedAt) }
}

// MARK: - Clipboard Widget

struct ClipboardWidget: Widget {
    let kind = "ClipboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClipboardTimelineProvider()) { entry in
            ClipboardWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName(WidgetL10n.clipboardDisplayName)
        .description(WidgetL10n.clipboardDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Clipboard Widget View

struct ClipboardWidgetView: View {
    let entry: ClipboardEntry
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
            if entry.recentItems.isEmpty {
                Spacer()
                WidgetEmptyState(icon: "doc.on.clipboard", message: WidgetL10n.clipboardNoItems)
                Spacer()
            } else {
                WidgetHeader(icon: "doc.on.clipboard", title: WidgetL10n.clipboardTitle, trailing: entry.updateString, color: .blue)

                Text(entry.recentItems.first?.text ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)

                HStack {
                    Label("\(entry.recentItems.count) \(WidgetL10n.clipboardItems)", systemImage: "tray.full")
                    Spacer()
                    Label(entry.recentItems.first?.isURL == true ? WidgetL10n.clipboardLink : WidgetL10n.clipboardText,
                          systemImage: entry.recentItems.first?.isURL == true ? "link" : "doc.text")
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(icon: "doc.on.clipboard", title: WidgetL10n.clipboardHistory, trailing: "\(entry.recentItems.count) \(WidgetL10n.clipboardItems) · \(entry.updateString)", color: .blue)

            if entry.recentItems.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(WidgetL10n.clipboardNoContent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.recentItems.prefix(3)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.isURL ? "link" : "doc.text")
                            .font(.system(size: 10))
                            .foregroundColor(item.isURL ? .blue : .secondary)
                            .frame(width: 16)

                        Text(item.text)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(timeAgo(item.timestamp))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)

                        // 复制按钮
                        Button(intent: ClipboardCopyIntent(text: item.text)) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return WidgetL10n.clipboardJustNow }
        if interval < 3600 { return "\(Int(interval / 60))\(WidgetL10n.clipboardMinutesAgo)" }
        return "\(Int(interval / 3600))\(WidgetL10n.clipboardHoursAgo)"
    }
}
