//
//  TimerWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Timer Timeline Provider

struct TimerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let entry = TimerEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Timer Entry

struct TimerEntry: TimelineEntry {
    let date: Date
    let type: TimerType
    let remainingSeconds: Int
    let isRunning: Bool
    let completedPomodoros: Int

    enum TimerType: String {
        case pomodoro, countdown, idle
    }

    static var placeholder: TimerEntry {
        TimerEntry(date: Date(), type: .pomodoro, remainingSeconds: 1500,
                   isRunning: true, completedPomodoros: 2)
    }

    static func fromUserDefaults() -> TimerEntry {
        let d = WidgetConstants.sharedDefaults
        let type = TimerType(rawValue: d.string(forKey: "widget_timer_type") ?? "idle") ?? .idle

        return TimerEntry(
            date: Date(),
            type: type,
            remainingSeconds: d.integer(forKey: "widget_timer_remaining"),
            isRunning: d.bool(forKey: "widget_timer_running"),
            completedPomodoros: d.integer(forKey: "widget_timer_pomodoros")
        )
    }

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var title: String {
        switch type {
        case .pomodoro: return "Pomodoro"
        case .countdown: return "Countdown"
        case .idle: return "Timer"
        }
    }

    var iconSystemName: String {
        switch type {
        case .pomodoro: return "timer"
        case .countdown: return "hourglass"
        case .idle: return "clock"
        }
    }

    var statusText: String {
        if type == .idle { return "Idle" }
        return isRunning ? "Running" : "Paused"
    }

    var statusColor: Color {
        if type == .idle { return .secondary }
        return isRunning ? .green : .orange
    }
}

// MARK: - Timer Widget

struct TimerWidget: Widget {
    let kind = "TimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerTimelineProvider()) { entry in
            TimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("计时器")
        .description("番茄钟和倒计时")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timer Widget View

struct TimerWidgetView: View {
    let entry: TimerEntry
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
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 20))
                .foregroundColor(entry.statusColor)

            Text(entry.formattedTime)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)

            Text(entry.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            if entry.type == .pomodoro && entry.completedPomodoros > 0 {
                Text("\(entry.completedPomodoros) done")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：时间
            VStack(spacing: 4) {
                Text(entry.formattedTime)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 100)

            Divider()

            // 右侧：状态
            VStack(alignment: .leading, spacing: 10) {
                // 运行状态
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.statusColor)
                        .frame(width: 6, height: 6)
                    Text(entry.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }

                // 番茄钟信息
                if entry.type == .pomodoro {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("\(entry.completedPomodoros) completed")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }

                // 倒计时信息
                if entry.type == .countdown {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Counting down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}
