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
        TimerEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        completion(TimerEntry.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        // 从 UserDefaults 读取计时器数据
        let entry = TimerEntry.fromUserDefaults()

        // 每 1 秒刷新一次（计时器需要精确显示）
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timer Entry

struct TimerEntry: TimelineEntry {
    let date: Date
    let type: TimerType
    let remainingSeconds: Int
    let isRunning: Bool
    let completedPomodoros: Int

    enum TimerType {
        case pomodoro
        case countdown
        case idle
    }

    static var placeholder: TimerEntry {
        TimerEntry(
            date: Date(),
            type: .pomodoro,
            remainingSeconds: 1500, // 25 分钟
            isRunning: true,
            completedPomodoros: 2
        )
    }

    static func fromUserDefaults() -> TimerEntry {
        let defaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
        let timerType = defaults.string(forKey: "widget_timer_type") ?? "idle"

        switch timerType {
        case "pomodoro":
            return TimerEntry(
                date: Date(),
                type: .pomodoro,
                remainingSeconds: defaults.integer(forKey: "widget_timer_remaining"),
                isRunning: defaults.bool(forKey: "widget_timer_running"),
                completedPomodoros: defaults.integer(forKey: "widget_timer_pomodoros")
            )
        case "countdown":
            return TimerEntry(
                date: Date(),
                type: .countdown,
                remainingSeconds: defaults.integer(forKey: "widget_timer_remaining"),
                isRunning: defaults.bool(forKey: "widget_timer_running"),
                completedPomodoros: 0
            )
        default:
            return TimerEntry(
                date: Date(),
                type: .idle,
                remainingSeconds: 0,
                isRunning: false,
                completedPomodoros: defaults.integer(forKey: "widget_timer_pomodoros")
            )
        }
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var title: String {
        switch type {
        case .pomodoro: return "番茄钟"
        case .countdown: return "倒计时"
        case .idle: return "计时器"
        }
    }

    var iconSystemName: String {
        switch type {
        case .pomodoro: return "timer"
        case .countdown: return "hourglass"
        case .idle: return "clock"
        }
    }
}

// MARK: - Timer Widget

struct TimerWidget: Widget {
    let kind: String = "TimerWidget"

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
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small View

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)

            Text(entry.formattedTime)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)

            Text(entry.title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if entry.type == .pomodoro {
                Text("\(entry.completedPomodoros) 个番茄")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Medium View

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：时间显示
            VStack(spacing: 4) {
                Text(entry.formattedTime)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Text(entry.title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()

            // 右侧：状态信息
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: entry.isRunning ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                    Text(entry.isRunning ? "运行中" : "已暂停")
                        .font(.system(size: 11))
                }
                .foregroundColor(entry.isRunning ? .green : .secondary)

                if entry.type == .pomodoro {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("已完成 \(entry.completedPomodoros) 个番茄")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }

                if entry.type == .countdown {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                        Text("倒计时中")
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

// MARK: - Preview

#Preview(as: .systemSmall) {
    TimerWidget()
} timeline: {
    TimerEntry.placeholder
}
