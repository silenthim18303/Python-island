//
//  IdleView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Idle View

/// 空闲态视图 — 紧凑胶囊：时间 · 番茄钟 · (音乐内容) · 倒计时 · 日期
struct IdleView: View {
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var musicService: MusicService
    @EnvironmentObject var lyricsService: LyricsService
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var pomodoroVisible: Bool {
        timerService.pomodoro.running || timerService.pomodoro.remaining < timerService.pomodoro.phaseDuration
    }

    private var countdownVisible: Bool {
        timerService.countdown.state != .idle
    }

    /// 播放中且有歌词
    private var hasLyrics: Bool {
        musicService.hasMedia
            && musicService.info.isPlaying
            && lyricsService.currentLyrics.lines.contains {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    /// 播放中（有歌曲名）
    private var isPlaying: Bool {
        musicService.hasMedia
            && musicService.info.isPlaying
            && !musicService.info.title.isEmpty
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(timeString)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .monospacedDigit()
                .fixedSize()
                .contentTransition(.numericText())
                .layoutPriority(4)

            if pomodoroVisible {
                timerPill(
                    icon: timerService.pomodoro.running ? "timer" : "pause.fill",
                    text: timerService.pomodoro.formattedTime,
                    tint: pomodoroPhaseColor,
                    progress: timerService.pomodoro.progress,
                    isActive: timerService.pomodoro.running
                )
                .transition(chipTransition)
                .layoutPriority(3)
            }

            if showsMusic {
                musicPill
                    .transition(chipTransition)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            if countdownVisible {
                timerPill(
                    icon: countdownIcon,
                    text: countdownText,
                    tint: countdownTint,
                    progress: countdownProgress,
                    isActive: timerService.countdown.state == .running
                )
                .transition(chipTransition)
                .layoutPriority(3)
            }

            Text(dateString)
                .font(.system(size: Theme.FontSize.caption, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(4)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.22), value: pomodoroVisible)
        .animation(.easeInOut(duration: 0.22), value: countdownVisible)
        .animation(.easeInOut(duration: 0.22), value: showsMusic)
        .animation(.easeInOut(duration: 0.18), value: musicDisplayText)
        .onReceive(timer) { currentTime = $0 }
    }

    private var musicPill: some View {
        HStack(spacing: 6) {
            musicGlyph

            MarqueeText(
                text: musicDisplayText,
                font: .system(size: Theme.FontSize.caption, weight: isPlaying ? .semibold : .medium),
                color: isPlaying ? .textPrimary : .textSecondary
            )
            .id(musicDisplayText)
        }
        .padding(.horizontal, 7)
        .frame(height: 20)
        .frame(minWidth: 72, maxWidth: .infinity)
        .background(
            Capsule()
                .fill(Color.white.opacity(isPlaying ? 0.10 : 0.07))
        )
        .overlay(
            Capsule()
                .stroke(musicTint.opacity(isPlaying ? 0.36 : 0.22), lineWidth: 0.5)
        )
        .clipped()
    }

    @ViewBuilder
    private var musicGlyph: some View {
        if hasLyrics {
            Image(systemName: "waveform")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(musicTint.opacity(0.95))
                .symbolEffect(.variableColor.iterative, isActive: true)
                .frame(width: 14, height: 14)
        } else if let artwork = musicService.info.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: isPlaying ? "music.note" : "pause.fill")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(musicTint.opacity(0.85))
                .frame(width: 14, height: 14)
        }
    }

    private func timerPill(
        icon: String,
        text: String,
        tint: Color,
        progress: Double,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 5) {
            CompactProgressIcon(systemName: icon, tint: tint, progress: progress, isActive: isActive)

            Text(text)
                .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                .foregroundColor(isActive ? .textPrimary : .textSecondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(
            Capsule()
                .fill(Color.white.opacity(isActive ? 0.11 : 0.07))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(isActive ? 0.42 : 0.24), lineWidth: 0.5)
        )
    }

    private var chipTransition: AnyTransition {
        .scale(scale: 0.94).combined(with: .opacity)
    }

    private var showsMusic: Bool {
        musicService.hasMedia && !musicDisplayText.isEmpty
    }

    private var musicDisplayText: String {
        if hasLyrics, let activeLyricText {
            return activeLyricText
        }

        let title = musicService.info.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }

        let artist = musicService.info.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isPlaying, !artist.isEmpty else { return title }
        return "\(title) · \(artist)"
    }

    private var activeLyricText: String? {
        let lyrics = lyricsService.currentLyrics
        guard let activeIndex = lyrics.activeLineIndex(at: musicService.info.elapsedTime) else { return nil }

        let text = lyrics.lines[activeIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var musicTint: Color {
        hasLyrics ? .appAccent : (isPlaying ? .white : .textTertiary)
    }

    private var countdownIcon: String {
        switch timerService.countdown.state {
        case .running: return "hourglass"
        case .paused: return "pause.fill"
        case .completed: return "checkmark"
        case .idle: return "hourglass"
        }
    }

    private var countdownText: String {
        timerService.countdown.state == .completed ? L10n.done : timerService.countdown.formattedRemaining
    }

    private var countdownTint: Color {
        switch timerService.countdown.state {
        case .running: return .appAccent
        case .paused: return .orange
        case .completed: return .green
        case .idle: return .textTertiary
        }
    }

    private var countdownProgress: Double {
        timerService.countdown.state == .completed ? 1 : timerService.countdown.progress
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

private struct CompactProgressIcon: View {
    let systemName: String
    let tint: Color
    let progress: Double
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 1.2)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint.opacity(isActive ? 0.95 : 0.62),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: systemName)
                .font(.system(size: 6.5, weight: .bold))
                .foregroundColor(tint.opacity(isActive ? 0.95 : 0.70))
        }
        .frame(width: 12, height: 12)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}
