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
    func placeholder(in context: Context) -> TimerEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) { completion(.placeholder) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let entry = TimerEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Timer Entry

struct TimerEntry: TimelineEntry {
    let date: Date
    let type: TimerType
    let remainingSeconds: Int
    let totalSeconds: Int
    let isRunning: Bool
    let completedPomodoros: Int
    let currentPhase: String
    let state: TimerState
    let targetDate: Date?
    let updatedAt: Date?

    enum TimerType: String { case pomodoro, countdown, idle }
    enum TimerState: String { case idle, running, paused, completed }

    static var placeholder: TimerEntry {
        TimerEntry(date: Date(), type: .pomodoro, remainingSeconds: 1500,
                   totalSeconds: 1500, isRunning: true, completedPomodoros: 2,
                   currentPhase: "专注", state: .running,
                   targetDate: Date().addingTimeInterval(1500), updatedAt: Date())
    }

    static func fromUserDefaults() -> TimerEntry {
        let type = TimerType(rawValue: WidgetConstants.string("widget_timer_type") ?? "idle") ?? .idle
        let storedRemaining = WidgetConstants.int("widget_timer_remaining")
        let total = WidgetConstants.int("widget_timer_total")
        let isRunning = WidgetConstants.bool("widget_timer_running")
        let state = TimerState(rawValue: WidgetConstants.string("widget_timer_state") ?? "") ?? (isRunning ? .running : .idle)
        let targetTimestamp = WidgetConstants.double("widget_timer_target_at")
        let targetDate = targetTimestamp > 0 ? Date(timeIntervalSince1970: targetTimestamp) : nil
        let remaining = Self.remainingSeconds(storedRemaining: storedRemaining, isRunning: isRunning, targetDate: targetDate)
        let ts = WidgetConstants.double("widget_timer_updated_at")

        return TimerEntry(
            date: Date(), type: type, remainingSeconds: remaining,
            totalSeconds: total > 0 ? total : (type == .pomodoro ? 1500 : remaining),
            isRunning: isRunning, completedPomodoros: WidgetConstants.int("widget_timer_pomodoros"),
            currentPhase: WidgetConstants.string("widget_timer_phase") ?? "",
            state: state, targetDate: targetDate,
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        )
    }

    private static func remainingSeconds(storedRemaining: Int, isRunning: Bool, targetDate: Date?) -> Int {
        guard isRunning, let targetDate else { return max(storedRemaining, 0) }
        return max(Int(ceil(targetDate.timeIntervalSinceNow)), 0)
    }

    var effectiveRemainingSeconds: Int {
        Self.remainingSeconds(storedRemaining: remainingSeconds, isRunning: isRunning, targetDate: targetDate)
    }

    var formattedTime: String {
        let clamped = max(effectiveRemainingSeconds, 0)
        let h = clamped / 3600
        let m = (clamped % 3600) / 60
        let s = clamped % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(max(Double(totalSeconds - effectiveRemainingSeconds) / Double(totalSeconds), 0), 1)
    }

    var updateString: String { WidgetFormat.relativeTime(updatedAt) }

    var totalTimeString: String {
        let clamped = max(totalSeconds, 0)
        let h = clamped / 3600
        let m = (clamped % 3600) / 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分"
    }

    var title: String {
        switch type {
        case .pomodoro: return currentPhase.isEmpty ? "番茄钟" : currentPhase
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

    var statusText: String {
        switch state {
        case .idle: return "空闲"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        }
    }

    var statusColor: Color {
        switch state {
        case .idle: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .completed: return .blue
        }
    }
}

// MARK: - Timer Widget

struct TimerWidget: Widget {
    let kind = "TimerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerTimelineProvider()) { entry in
            TimerWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName("计时器")
        .description("番茄钟和倒计时")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        case .systemLarge: largeView
        default: smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(icon: entry.iconSystemName, title: entry.title, trailing: entry.statusText, color: entry.statusColor)

            if entry.type == .idle {
                Spacer()
                WidgetEmptyState(icon: "clock", message: "暂无计时任务")
                Spacer()
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 4)
                        .frame(width: 58, height: 58)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(entry.statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        timerText(size: 14)
                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(entry.type == .pomodoro ? "\(entry.completedPomodoros) 个番茄完成" : "总时长 \(entry.totalTimeString)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(icon: entry.iconSystemName, title: entry.title, trailing: "\(entry.statusText) · \(entry.updateString)", color: entry.statusColor)

            if entry.type == .idle {
                Spacer()
                WidgetEmptyState(icon: "clock", message: "番茄钟和倒计时空闲中")
                Spacer()
            } else {
                HStack(spacing: 14) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
                                .frame(width: 66, height: 66)
                            Circle()
                                .trim(from: 0, to: entry.progress)
                                .stroke(entry.statusColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .frame(width: 66, height: 66)
                                .rotationEffect(.degrees(-90))
                            timerText(size: 18)
                        }
                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 76)

                    Divider()

                    VStack(spacing: 7) {
                        WidgetInfoRow(icon: "flag.checkered", title: "状态", value: entry.statusText, color: entry.statusColor)
                        WidgetInfoRow(icon: "clock.arrow.circlepath", title: "总时长", value: entry.totalTimeString, color: .blue)
                        if entry.type == .pomodoro {
                            WidgetInfoRow(icon: "checkmark.circle.fill", title: "完成", value: "\(entry.completedPomodoros) 个番茄", color: .green)
                        } else {
                            WidgetInfoRow(icon: "hourglass", title: "剩余", value: entry.formattedTime, color: .orange)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(icon: entry.iconSystemName, title: entry.title,
                         trailing: "\(entry.statusText) · \(entry.updateString)", color: entry.statusColor)

            if entry.type == .idle {
                Spacer()
                WidgetEmptyState(icon: "clock", message: "番茄钟和倒计时空闲中\n从主应用启动计时")
                Spacer()
            } else {
                // 大号进度环
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: entry.progress)
                            .stroke(entry.statusColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 4) {
                            timerText(size: 22)
                            Text("\(Int(entry.progress * 100))%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                // 详细信息网格
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 8) {
                    TimerDetailCard(icon: "flag.checkered", title: "状态", value: entry.statusText, color: entry.statusColor)
                    TimerDetailCard(icon: "clock.arrow.circlepath", title: "总时长", value: entry.totalTimeString, color: .blue)
                    if entry.type == .pomodoro {
                        TimerDetailCard(icon: "checkmark.circle.fill", title: "已完成", value: "\(entry.completedPomodoros) 个番茄", color: .green)
                        TimerDetailCard(icon: "timer", title: "当前阶段", value: entry.currentPhase, color: .orange)
                    } else {
                        TimerDetailCard(icon: "hourglass", title: "剩余时间", value: entry.formattedTime, color: .orange)
                        TimerDetailCard(icon: "clock", title: "已用时间",
                                        value: formatElapsed(), color: .blue)
                    }
                }
            }
        }
        .padding()
    }

    private func formatElapsed() -> String {
        let elapsed = max(entry.totalSeconds - entry.effectiveRemainingSeconds, 0)
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    @ViewBuilder
    private func timerText(size: CGFloat) -> some View {
        if entry.isRunning, let targetDate = entry.targetDate, targetDate > Date() {
            Text(targetDate, style: .timer)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text(entry.formattedTime)
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Timer Detail Card

private struct TimerDetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}
