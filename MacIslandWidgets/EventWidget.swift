//
//  EventWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Event Timeline Provider

struct EventTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EventEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (EventEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EventEntry>) -> Void) {
        let entry = EventEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Event Entry

struct EventEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]

    struct EventItem: Identifiable {
        let id: String
        let name: String
        let targetDate: Date
        let type: EventType

        enum EventType: String {
            case countdown, birthday, anniversary, holiday, exam
        }

        var daysRemaining: Int {
            Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
        }

        var isPast: Bool { daysRemaining < 0 }
        var isToday: Bool { daysRemaining == 0 }

        var iconSystemName: String {
            switch type {
            case .countdown: return "clock"
            case .birthday: return "gift"
            case .anniversary: return "heart"
            case .holiday: return "star"
            case .exam: return "book"
            }
        }

        var daysString: String {
            if isToday { return "Today!" }
            if isPast { return "\(-daysRemaining) days ago" }
            return "\(daysRemaining) days"
        }
    }

    static var placeholder: EventEntry {
        let now = Date()
        return EventEntry(
            date: now,
            events: [
                EventItem(id: "1", name: "Birthday Party", targetDate: Calendar.current.date(byAdding: .day, value: 5, to: now)!, type: .birthday),
                EventItem(id: "2", name: "Project Deadline", targetDate: Calendar.current.date(byAdding: .day, value: 12, to: now)!, type: .countdown),
                EventItem(id: "3", name: "Vacation", targetDate: Calendar.current.date(byAdding: .day, value: 30, to: now)!, type: .holiday),
            ]
        )
    }

    static func fromUserDefaults() -> EventEntry {
        let d = WidgetConstants.sharedDefaults
        var events: [EventItem] = []

        if let data = d.data(forKey: "widget_event_items"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in json {
                if let id = dict["id"] as? String,
                   let name = dict["name"] as? String,
                   let timestamp = dict["targetDate"] as? TimeInterval,
                   let typeStr = dict["type"] as? String {
                    let type = EventItem.EventType(rawValue: typeStr) ?? .countdown
                    events.append(EventItem(
                        id: id,
                        name: name,
                        targetDate: Date(timeIntervalSince1970: timestamp),
                        type: type
                    ))
                }
            }
        }

        // 按日期排序，最近的在前
        events.sort { $0.targetDate < $1.targetDate }

        return EventEntry(date: Date(), events: events)
    }
}

// MARK: - Event Widget

struct EventWidget: Widget {
    let kind = "EventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventTimelineProvider()) { entry in
            EventWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("倒数日")
        .description("即将到来的事件和倒计时")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Event Widget View

struct EventWidgetView: View {
    let entry: EventEntry
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
            if let first = entry.events.first {
                Image(systemName: first.iconSystemName)
                    .font(.system(size: 20))
                    .foregroundColor(eventColor(first.type))

                Text(first.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(first.daysString)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                if entry.events.count > 1 {
                    Text("+\(entry.events.count - 1) more")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            } else {
                WidgetEmptyState(icon: "calendar", message: "No events")
            }
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text("Events")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(entry.events.count) events")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if entry.events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No upcoming events")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.events.prefix(4)) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.iconSystemName)
                            .font(.system(size: 12))
                            .foregroundColor(eventColor(event.type))
                            .frame(width: 20)

                        Text(event.name)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(event.daysString)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(event.isPast ? .secondary : .primary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }

    private func eventColor(_ type: EventEntry.EventItem.EventType) -> Color {
        switch type {
        case .countdown: return .blue
        case .birthday: return .pink
        case .anniversary: return .red
        case .holiday: return .yellow
        case .exam: return .orange
        }
    }
}
