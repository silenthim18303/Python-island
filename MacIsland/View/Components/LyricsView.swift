//
//  LyricsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Lyrics View

/// 歌词态视图 — 横向绕刘海胶囊：封面 + 歌词居中 + 进度/音波
struct LyricsView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var musicService: SystemMusicService
    @EnvironmentObject var lyricsService: LyricsService

    var body: some View {
        // 自定义布局：左封面 + 中歌词(居中覆盖刘海区) + 右音波
        HStack(spacing: 0) {
            // 左侧：封面图标
            musicIcon
                .padding(.leading, Theme.Spacing.sm)

            Spacer(minLength: Theme.Spacing.xs)

            // 中间：歌词行居中显示
            centerContent
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.xs)

            // 右侧：进度 + 音波动画
            rightSection
                .padding(.trailing, Theme.Spacing.sm)
        }
    }

    // MARK: - Music Icon

    private var musicIcon: some View {
        Group {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        if musicService.hasMedia {
            let lyrics = lyricsService.currentLyrics
            let elapsed = musicService.info.elapsedTime

            if !lyrics.lines.isEmpty,
               let activeIndex = lyrics.activeLineIndex(at: elapsed) {
                // 当前歌词行（超长时自动滚动）
                MarqueeText(
                    text: lyrics.lines[activeIndex].text,
                    font: .system(size: Theme.FontSize.caption, weight: .semibold),
                    color: .white.opacity(0.9)
                )
                .id(activeIndex)
            } else {
                // Fallback: show song title + artist
                HStack(spacing: Theme.Spacing.xs) {
                    Text(musicService.info.title)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Text("-")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textQuaternary)

                    Text(musicService.info.artist)
                        .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text(L10n.musicNoPlayback)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Right Section

    private var rightSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if musicService.hasMedia && musicService.info.duration > 0 {
                MiniProgressDot(progress: musicService.info.progress)
            }

            if musicService.info.isPlaying {
                AudioVisualizer()
            }
        }
    }

}

// MARK: - Mini Progress Dot

struct MiniProgressDot: View {
    let progress: Double

    private let trackWidth: CGFloat = 16
    private let dotSize: CGFloat = 3

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.12))
                .frame(width: trackWidth, height: 2)

            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: dotSize, height: dotSize)
                .offset(x: max(0, min(trackWidth - dotSize, CGFloat(progress) * (trackWidth - dotSize))))
        }
        .frame(width: trackWidth, height: max(2, dotSize))
    }
}

// MARK: - Audio Visualizer

struct AudioVisualizer: View {
    @State private var phases: [Bool] = [false, false, false, false]

    private let delays: [Double] = [0.0, 0.12, 0.24, 0.08]
    private let baseHeight: CGFloat = 3
    private let maxHeight: CGFloat = 14
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.55))
                    .frame(width: barWidth, height: phases[index] ? maxHeight : baseHeight)
                    .animation(
                        .easeInOut(duration: 0.35 + Double(index) * 0.05)
                        .repeatForever(autoreverses: true)
                        .delay(delays[index]),
                        value: phases[index]
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            for i in 0..<4 {
                phases[i] = true
            }
        }
    }
}
