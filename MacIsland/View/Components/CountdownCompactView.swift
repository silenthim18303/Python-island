//
//  CountdownCompactView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

// MARK: - Countdown Compact View

/// 横向倒计时缩小态 — 绕开刘海：左侧沙漏图标，右侧剩余时间
struct CountdownCompactView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var timerService: TimerService

    var body: some View {
        WideNotchLayout {
            // 左侧：状态图标（运行=沙漏 / 暂停=暂停符号）
            Image(systemName: timerService.countdown.state == .paused ? "pause.fill" : "hourglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        } trailing: {
            // 右侧：剩余时间
            Text(timerService.countdown.formattedRemaining)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
