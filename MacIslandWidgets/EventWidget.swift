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
    let updatedAt: Date?
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
            if isToday { return WidgetL10n.eventToday }
            if isPast { return "\(-daysRemaining)\(WidgetL10n.eventDaysAgo)" }
            return "\(daysRemaining)\(WidgetL10n.eventDays)"
        }

        var typeTitle: String {
            switch type {
            case .countdown: return "倒数"
            case .birthday: return "生日"
            case .anniversary: return "纪念"
            case .holiday: return "假期"
            case .exam: return "考试"
            }
        }

        var dateString: String {
            targetDate.formatted(.dateTime.month().day())
        }
    }

    static var placeholder: EventEntry {
        let now = Date()
        return EventEntry(
            date: now,
            updatedAt: now,
            events: [
                EventItem(id: "1", name: "生日聚会", targetDate: Calendar.current.date(byAdding: .day, value: 5, to: now)!, type: .birthday),
                EventItem(id: "2", name: "项目截止", targetDate: Calendar.current.date(byAdding: .day, value: 12, to: now)!, type: .countdown),
                EventItem(id: "3", name: "假期开始", targetDate: Calendar.current.date(byAdding: .day, value: 30, to: now)!, type: .holiday),
            ]
        )
    }

    static func fromUserDefaults() -> EventEntry {
        let ts = WidgetConstants.double("widget_event_updated_at")
        var events: [EventItem] = []

        if let data = WidgetConstants.data("widget_event_items"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in json {
                if let id = dict["id"] as? String,
                   let name = dict["name"] as? String,
                   let timestamp = dict["targetDate"] as? TimeInterval,
                   let typeStr = dict["type"] as? String {
                    let type = EventItem.EventType(rawValue: typeStr) ?? .countdown
                    events.append(EventItem(id: id, name: name, targetDate: Date(timeIntervalSince1970: timestamp), type: type))
                }
            }
        }

        events.sort { $0.targetDate < $1.targetDate }

        return EventEntry(
            date: Date(),
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil,
            events: events
        )
    }

    var updateString: String { WidgetFormat.relativeTime(updatedAt) }
}

// MARK: - Event Widget

struct EventWidget: Widget {
    let kind = "EventWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EventTimelineProvider()) { entry in
            EventWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName(WidgetL10n.eventDisplayName)
        .description(WidgetL10n.eventDescription)
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
        VStack(alignment: .leading, spacing: 8) {
            if let first = entry.events.first {
                WidgetHeader(icon: first.iconSystemName, title: first.typeTitle, trailing: entry.updateString, color: eventColor(first.type))

                Text(first.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(first.daysString)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack {
                    Text(first.dateString)
                    Spacer()
                    if entry.events.count > 1 {
                        Text("+\(entry.events.count - 1)")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            } else {
                Spacer()
                WidgetEmptyState(icon: "calendar", message: WidgetL10n.eventNoEvents)
                Spacer()
            }
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(icon: "calendar", title: WidgetL10n.eventDisplayName, trailing: "\(entry.events.count) \(WidgetL10n.eventEvents) · \(entry.updateString)", color: .blue)

            if entry.events.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text(WidgetL10n.eventNoEvents)
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

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(event.daysString)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(event.isPast ? .secondary : .primary)
                            Text(event.dateString)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
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
