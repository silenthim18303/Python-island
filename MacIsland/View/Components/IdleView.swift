//
//  IdleView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Idle View

/// 空闲态视图 — 紧凑胶囊：时间 · 番茄钟 · (歌词滚动) · 倒计时 · 日期
struct IdleView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var musicService: SystemMusicService
    @EnvironmentObject var lyricsService: LyricsService

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var pomRunning: Bool { timerService.pomodoro.running }
    private var cdRunning: Bool { timerService.countdown.state == .running }
    private var hasLyrics: Bool {
        musicService.hasMedia && !lyricsService.currentLyrics.lines.isEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：时间
            Text(timeString)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .monospacedDigit()

            // 番茄钟徽章
            if pomRunning {
                HStack(spacing: 3) {
                    Circle()
                        .fill(pomodoroPhaseColor)
                        .frame(width: 4, height: 4)
                    Text(timerService.pomodoro.formattedTime)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                }
                .padding(.leading, Theme.Spacing.sm)
            }

            // 中间：歌词滚动（占据剩余空间）
            if hasLyrics {
                lyricsScroll
                    .padding(.leading, Theme.Spacing.sm)
            }

            // 倒计时徽章
            if cdRunning {
                HStack(spacing: 3) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(timerService.countdown.formattedRemaining)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .monospacedDigit()
                }
                .padding(.leading, hasLyrics ? Theme.Spacing.xs : Theme.Spacing.sm)
            }

            // 右侧：日期
            Text(dateString)
                .font(.system(size: Theme.FontSize.caption, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .padding(.leading, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.FontSize.caption)
        .onReceive(timer) { currentTime = $0 }
    }

    // MARK: - Lyrics Scroll

    /// 歌词滚动显示：当前歌词行，超长时跑马灯滚动
    private var lyricsScroll: some View {
        let elapsed = musicService.info.elapsedTime
        let lyrics = lyricsService.currentLyrics

        return Group {
            if let activeIndex = lyrics.activeLineIndex(at: elapsed) {
                MarqueeText(
                    text: lyrics.lines[activeIndex].text,
                    font: .system(size: Theme.FontSize.caption, weight: .medium),
                    color: .white.opacity(0.7)
                )
                .id(activeIndex)
            } else {
                // 无匹配歌词时显示歌名
                MarqueeText(
                    text: musicService.info.title,
                    font: .system(size: Theme.FontSize.caption, weight: .medium),
                    color: .white.opacity(0.5)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 14)
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
            .replacingOccurrences(of: "星期", with: L10n.dateFormatWeekday)
    }
}
