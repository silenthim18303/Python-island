//
//  IdleView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Idle View

/// 空闲态视图 — 时间 + 日期，嵌入刘海区域；番茄钟/倒计时运行时中间显示
struct IdleView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var timerService: TimerService

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        compactLayout
            .onReceive(timer) { currentTime = $0 }
    }

    // MARK: - Compact Layout（紧凑居中：时间 + [番茄钟/倒计时] + 日期）

    private var compactLayout: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 时间
            Text(timeString)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .monospacedDigit()

            // 中间：番茄钟 > 倒计时 > 分隔点
            middleContent

            // 日期
            Text(dateString)
                .font(.system(size: Theme.FontSize.caption, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    /// 中间内容：番茄钟 > 倒计时 > 两者同时 > 分隔点
    @ViewBuilder
    private var middleContent: some View {
        let pomRunning = timerService.pomodoro.running
        let cdRunning = timerService.countdown.state == .running

        if pomRunning && cdRunning {
            // 两者同时运行：左番茄 · 右倒计时
            HStack(spacing: Theme.Spacing.xs) {
                HStack(spacing: 2) {
                    Text(timerService.pomodoro.phase.rawValue)
                        .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                        .foregroundColor(pomodoroPhaseColor.opacity(0.8))
                    Text(timerService.pomodoro.formattedTime)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .monospacedDigit()
                }
                Circle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 2.5, height: 2.5)
                Text(timerService.countdown.formattedRemaining)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .monospacedDigit()
            }
            .lineLimit(1)
        } else if pomRunning {
            // 仅番茄钟
            HStack(spacing: 3) {
                Text(timerService.pomodoro.phase.rawValue)
                    .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                    .foregroundColor(pomodoroPhaseColor.opacity(0.8))
                Text(timerService.pomodoro.formattedTime)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .monospacedDigit()
            }
            .lineLimit(1)
        } else if cdRunning {
            // 仅倒计时
            Text(timerService.countdown.formattedRemaining)
                .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .monospacedDigit()
                .lineLimit(1)
        } else {
            // 无计时器运行
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: 2.5, height: 2.5)
        }
    }

    private var pomodoroPhaseColor: Color {
        switch timerService.pomodoro.phase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    // MARK: - Private Properties

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d EEEE"
        return formatter.string(from: currentTime)
            .replacingOccurrences(of: "星期", with: "周")
    }
}
