//
//  LyricsView.swift
//  MacIsland
//
//  歌词态视图 — 紧凑胶囊：时间 · 番茄钟 · 歌词/歌曲名 · 倒计时 ·日期
//  与 IdleView 布局一致，中间区域显示音乐内容
//

import SwiftUI
import Combine

struct LyricsView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var musicService: MusicService
    @EnvironmentObject var lyricsService: LyricsService
    @EnvironmentObject var timerService: TimerService
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var pomRunning: Bool { timerService.pomodoro.running }
    private var cdRunning: Bool { timerService.countdown.state == .running }

    /// 播放中且有歌词
    private var hasLyrics: Bool {
        musicService.hasMedia
            && musicService.info.isPlaying
            && !lyricsService.currentLyrics.lines.isEmpty
            && lyricsService.currentLyrics.lines.first?.text != ""
    }

    /// 播放中（有歌曲名）
    private var isPlaying: Bool {
        musicService.hasMedia
            && musicService.info.isPlaying
            && !musicService.info.title.isEmpty
    }

    /// 暂停中
    private var isPaused: Bool {
        musicService.hasMedia
            && !musicService.info.isPlaying
            && !musicService.info.title.isEmpty
    }

    var body: some View {
        HStack(spacing: 4) {
            // 1. 时间
            Text(timeString)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .monospacedDigit()
                .fixedSize()

            // 2. 番茄钟徽章
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
                .fixedSize()
            }

            Spacer(minLength: 0)

            // 3. 音乐内容（歌词或歌曲名）
            if hasLyrics {
                let lyrics = lyricsService.currentLyrics
                let elapsed = musicService.info.elapsedTime
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .symbolEffect(.variableColor.iterative, isActive: true)

                    if let activeIndex = lyrics.activeLineIndex(at: elapsed) {
                        Text(lyrics.lines[activeIndex].text)
                            .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .id(activeIndex)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            } else if isPlaying {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Text(musicService.info.title)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            } else if isPaused {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Text(musicService.info.title)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            // 4. 倒计时徽章
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
                .fixedSize()
            }

            // 5. 日期
            Text(dateString)
                .font(.system(size: Theme.FontSize.caption, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.3), value: hasLyrics)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
        .onReceive(timer) { currentTime = $0 }
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
        formatter.locale = Locale(identifier: L10n.localeIdentifier)
        formatter.dateFormat = L10n.dateFormatShort
        return formatter.string(from: currentTime)
    }
}
