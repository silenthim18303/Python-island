//
//  ExpandedView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Expanded View

/// 展开态视图 — 概览/音乐/工具/监控
struct ExpandedView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var weatherService: QWeatherService
    @EnvironmentObject var musicService: SystemMusicService
    @EnvironmentObject var monitorService: SystemMonitorServiceImpl

    @State private var selectedTab: Tab = .overview

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case overview = "概览"
        case music = "音乐"
        case tools = "工具"
        case monitor = "监控"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabBar
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            // 读取来源形态指定的初始 Tab（如从倒计时态展开时自动切到工具）
            if let tabName = store.expandedInitialTab,
               let tab = Tab.allCases.first(where: { $0.rawValue == tabName }) {
                selectedTab = tab
                store.expandedInitialTab = nil
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // 展开到 MaxExpand
            Button { store.setMaxExpand() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help("展开更多功能")

            Spacer()

            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 4)

            Spacer()

            // Collapse
            Button { store.setIdle() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == tab
                                ? Capsule().fill(.white.opacity(0.15))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview: overviewTab
        case .music: musicTab
        case .tools: toolsTab
        case .monitor: monitorTab
        }
    }

    // MARK: - Overview Tab

    private var overviewTab: some View {
        VStack(spacing: 12) {
            dateTimeSection
            weatherCards

            if musicService.hasMedia {
                nowPlayingCard
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var dateTimeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate("yyyy年M月d日 EEEE"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(formatDate("HH:mm:ss"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var weatherCards: some View {
        HStack(spacing: 12) {
            WeatherCard(
                icon: weatherService.weather.iconSystemName,
                temp: "\(Int(weatherService.weather.temperature))°C",
                desc: weatherService.weather.description
            )
            WeatherCard(
                icon: "wind",
                temp: String(format: "%.0f km/h", weatherService.weather.windSpeed),
                desc: "风速"
            )
            WeatherCard(
                icon: "humidity.fill",
                temp: "\(weatherService.weather.humidity)%",
                desc: "湿度"
            )
        }
    }

    private var nowPlayingCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .cornerRadius(Theme.Radius.sm)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.textQuaternary)
                    .frame(width: 36, height: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(musicService.info.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(musicService.info.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button { musicService.togglePlay() } label: {
                Image(systemName: musicService.info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
    }

    // MARK: - Music Tab

    private var musicTab: some View {
        VStack(spacing: 0) {
            // 专辑封面 + 歌曲信息（始终显示，无播放时为空占位）
            HStack(spacing: 12) {
                albumArtSmall
                songInfoCompact
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer().frame(height: 10)

            // 可拖拽进度条（无播放时显示 0%）
            DraggableProgressView(
                progress: musicService.info.progress,
                elapsed: musicService.info.formattedElapsed,
                duration: musicService.info.formattedDuration,
                totalDuration: musicService.info.duration,
                onSeek: { fraction in
                    musicService.seek(to: fraction * musicService.info.duration)
                }
            )
            .padding(.horizontal, 20)

            Spacer().frame(height: 10)

            // 播放控制（始终可用）
            musicPlaybackControls

            Spacer().frame(height: 8)

            // 音量 + Shuffle / Repeat（始终显示）
            HStack(spacing: 12) {
                shuffleRepeatCompact

                Spacer()

                VolumeControlView(volume: musicService.info.volume) { newVolume in
                    musicService.setVolume(newVolume)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Album Art (Small)

    private var albumArtSmall: some View {
        Group {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .cornerRadius(Theme.Radius.sm)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color.fillSubtle)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.textQuaternary)
                    )
            }
        }
    }

    // MARK: - Song Info Compact

    private var songInfoCompact: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(musicService.info.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(musicService.info.artist)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
        }
    }

    // MARK: - Shuffle/Repeat Compact

    private var shuffleRepeatCompact: some View {
        HStack(spacing: 12) {
            ToggleButton(
                systemName: "shuffle",
                isActive: musicService.info.isShuffle,
                action: { musicService.toggleShuffle() }
            )

            ToggleButton(
                systemName: repeatIconName,
                isActive: musicService.info.repeatMode != 0,
                action: { musicService.cycleRepeat() }
            )
        }
    }


    // MARK: - Album Art

    private var albumArtSection: some View {
        Group {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(Theme.Radius.lg)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .fill(Color.fillSubtle)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.2))
                    )
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Song Info

    private var songInfoSection: some View {
        VStack(spacing: 4) {
            Text(musicService.info.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(musicService.info.artist)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)

            if !musicService.info.album.isEmpty {
                Text(musicService.info.album)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Playback Controls

    private var musicPlaybackControls: some View {
        HStack(spacing: 24) {
            // Previous
            PlaybackButton(systemName: "backward.fill", size: 18) {
                musicService.previousTrack()
            }

            // Play/Pause (larger, prominent)
            PlaybackButton(systemName: musicService.info.isPlaying ? "pause.fill" : "play.fill", size: 32, isPrimary: true) {
                musicService.togglePlay()
            }

            // Next
            PlaybackButton(systemName: "forward.fill", size: 18) {
                musicService.nextTrack()
            }
        }
    }

    // MARK: - Shuffle / Repeat Bar

    private var shuffleRepeatBar: some View {
        HStack(spacing: 40) {
            Button { musicService.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 14))
                    .foregroundColor(musicService.info.isShuffle ? .accentColor : .white.opacity(0.4))
            }

            Button { musicService.cycleRepeat() } label: {
                Image(systemName: repeatIconName)
                    .font(.system(size: 14))
                    .foregroundColor(musicService.info.repeatMode != 0 ? .accentColor : .white.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
    }

    private var repeatIconName: String {
        switch musicService.info.repeatMode {
        case 1: return "repeat"
        case 2: return "repeat.1"
        default: return "repeat"
        }
    }

    // MARK: - Tools Tab

    private var toolsTab: some View {
        TimerView()
    }

    // MARK: - Monitor Tab

    private var monitorTab: some View {
        RunCatMonitorView()
    }

    // MARK: - Helper

    private func formatDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: Date())
    }

}
// MARK: - Playback Button

/// Polished playback control button
struct PlaybackButton: View {
    let systemName: String
    var size: CGFloat = 18
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: isPrimary ? 48 : 36, height: isPrimary ? 48 : 36)
                .background(
                    Circle()
                        .fill(isPrimary
                            ? Color.white.opacity(isHovering ? 0.25 : 0.15)
                            : Color.white.opacity(isHovering ? 0.15 : 0.06))
                )
                .scaleEffect(isPressed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Toggle Button

/// Toggle button for shuffle/repeat with active state
struct ToggleButton: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    isActive
                        ? .accentColor
                        : .white.opacity(isHovering ? 0.6 : 0.35)
                )
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive
                            ? Color.accentColor.opacity(isHovering ? 0.2 : 0.1)
                            : Color.white.opacity(isHovering ? 0.1 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Draggable Progress View

/// 可拖拽的播放进度条
struct DraggableProgressView: View {
    let progress: Double
    let elapsed: String
    let duration: String
    let totalDuration: TimeInterval
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragFraction: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let trackHeight: CGFloat = 4

                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                        .frame(height: trackHeight)

                    // 已播放部分
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: width * currentFraction, height: trackHeight)

                    // 拖拽手柄
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .offset(x: width * currentFraction - 6)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
                .frame(height: trackHeight)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().size(CGSize(width: width, height: 20)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(value.location.x / width, 0), 1)
                            dragFraction = fraction
                        }
                        .onEnded { value in
                            let fraction = min(max(value.location.x / width, 0), 1)
                            onSeek(fraction)
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(isDragging ? formatDragTime(dragFraction) : elapsed)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                Text(duration)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var currentFraction: Double {
        isDragging ? dragFraction : progress
    }

    private func formatDragTime(_ fraction: Double) -> String {
        let totalSeconds = Int(fraction * totalDuration)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - Volume Control View

/// 音量控制滑块
struct VolumeControlView: View {
    let volume: Float
    let onVolumeChange: (Float) -> Void

    @State private var isDragging = false
    @State private var dragVolume: Float = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 16)

            GeometryReader { geometry in
                let width = geometry.size.width
                let trackHeight: CGFloat = 3

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.15))
                        .frame(height: trackHeight)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.7))
                        .frame(width: width * CGFloat(currentVolume), height: trackHeight)
                }
                .frame(height: trackHeight)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().size(CGSize(width: width, height: 16)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(Float(value.location.x / width), 0), 1)
                            dragVolume = fraction
                            onVolumeChange(fraction)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 16)

            Text("\(Int(currentVolume * 100))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var currentVolume: Float {
        isDragging ? dragVolume : volume
    }

    private var volumeIcon: String {
        if currentVolume <= 0 { return "speaker.slash.fill" }
        if currentVolume < 0.33 { return "speaker.wave.1.fill" }
        if currentVolume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Weather Card

/// 天气卡片组件
struct WeatherCard: View {
    let icon: String
    let temp: String
    let desc: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            Text(temp)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text(desc)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(Color.fillSubtle)
        )
    }
}

// MARK: - Monitor Row

/// 监控行组件
struct MonitorRow: View {
    let icon: String
    let label: String
    let value: String
    let percent: Double

    var body: some View {
        VStack(spacing: Theme.Spacing.xs + 2) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: Theme.FontSize.body - 1))
                    .foregroundColor(.textSecondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: Theme.FontSize.body - 1, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(value)
                    .font(.system(size: Theme.FontSize.body - 1, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geometry.size.width * percent)
                }
            }
            .frame(height: 4)
        }
    }

    private var barColor: Color {
        if percent > 0.8 { return .red }
        if percent > 0.6 { return .orange }
        return .green
    }
}
