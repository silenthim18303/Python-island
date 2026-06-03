//
//  CountdownCompactView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

// MARK: - Countdown Compact View

/// 横向倒计时缩小态 — 绕开刘海：左侧沙漏图标，右侧剩余时间 + 暂停/继续按钮
struct CountdownCompactView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var timerService: TimerService

    var body: some View {
        WideNotchLayout {
            // 左侧：状态图标
            Image(systemName: statusIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(statusColor)
        } trailing: {
            // 右侧：剩余时间 + 操作按钮
            HStack(spacing: Theme.Spacing.xs) {
                Text(timerService.countdown.formattedRemaining)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                    .monospacedDigit()
                    .lineLimit(1)

                if timerService.countdown.state == .completed {
                    // 完成态：显示重置按钮
                    Button { timerService.resetCountdown() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                } else {
                    // 运行/暂停态：暂停/继续按钮
                    Button {
                        if timerService.countdown.state == .running {
                            timerService.pauseCountdown()
                        } else {
                            timerService.resumeCountdown()
                        }
                    } label: {
                        Image(systemName: timerService.countdown.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusIcon: String {
        switch timerService.countdown.state {
        case .running:   return "hourglass"
        case .paused:    return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .idle:      return "hourglass"
        }
    }

    private var statusColor: Color {
        timerService.countdown.state == .completed ? .green : .white.opacity(0.8)
    }
}
