//
//  ExpandedView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Expanded View

/// 展开态视图 — 概览/音乐/工具(番茄钟+倒计时)/监控/股票
struct ExpandedView: View {
    @ObservedObject var store: IslandStore
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var weatherService: QWeatherService
    @EnvironmentObject var musicService: SystemMusicService
    @EnvironmentObject var monitorService: SystemMonitorServiceImpl
    @EnvironmentObject var stockStore: StockStore
    @EnvironmentObject var stockService: StockServiceImpl

    @State private var selectedTab: Tab = .overview
    @ObservedObject private var loc = LocalizationManager.shared

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case overview = "overview"
        case music = "music"
        case tools = "tools"
        case monitor = "monitor"
        case stock = "stock"

        var displayName: String {
            switch self {
            case .overview: return L10n.taboverview
            case .music: return L10n.tabmusic
            case .tools: return L10n.tabToolbox
            case .monitor: return L10n.monitorTitle
            case .stock: return L10n.stockTitle
            }
        }

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .music: return "music.note"
            case .tools: return "clock"
            case .monitor: return "desktopcomputer"
            case .stock: return "chart.line.uptrend.xyaxis"
            }
        }

        /// 是否需要 ScrollView（内容可能超出窗口）
        var needsScroll: Bool {
            switch self {
            case .overview, .stock: return true
            case .music, .tools, .monitor: return false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabBar

            if selectedTab.needsScroll {
                ScrollView {
                    tabContent
                        .frame(maxWidth: .infinity)
                }
            } else {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
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
            Button { store.setMaxExpand() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .help(L10n.open)

            Spacer()

            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 36, height: 4)

            Spacer()

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.displayName)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 12)
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
            .padding(.horizontal, 16)
        }
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
        case .stock: stockTab
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

            if !stockStore.watchlist.isEmpty {
                StockMiniCard()
                    .environmentObject(stockStore)
                    .environmentObject(stockService)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var dateTimeSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(L10n.dateFormatCN))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(formatDate("HH:mm:ss"))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private var weatherCards: some View {
        HStack(spacing: 8) {
            weatherCard(
                icon: weatherService.weather.iconSystemName,
                value: "\(Int(weatherService.weather.temperature))°C",
                label: weatherService.weather.description,
                color: .yellow
            )
            weatherCard(
                icon: "wind",
                value: String(format: "%.0f km/h", weatherService.weather.windSpeed),
                label: L10n.weatherWind,
                color: .cyan
            )
            weatherCard(
                icon: "humidity.fill",
                value: "\(weatherService.weather.humidity)%",
                label: L10n.weatherHumidity,
                color: .blue
            )
        }
    }

    private func weatherCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
    }

    private var nowPlayingCard: some View {
        HStack(spacing: 10) {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.purple.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(Image(systemName: "music.note").foregroundColor(.purple))
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
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
    }

    // MARK: - Music Tab

    private var musicTab: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                albumArtSmall
                songInfoCompact
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer().frame(height: 10)

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

            musicPlaybackControls

            Spacer().frame(height: 8)

            HStack(spacing: 12) {
                shuffleRepeatCompact
                Spacer()
                VolumeControlView(volume: musicService.info.volume) { newVolume in
                    musicService.setVolume(newVolume)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var albumArtSmall: some View {
        Group {
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }

    private var songInfoCompact: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(musicService.info.title.isEmpty ? L10n.musicLyrics : musicService.info.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(musicService.info.artist.isEmpty ? "—" : musicService.info.artist)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
        }
    }

    private var shuffleRepeatCompact: some View {
        HStack(spacing: 12) {
            MusicToggleButton(
                systemName: "shuffle",
                isActive: musicService.info.isShuffle,
                action: { musicService.toggleShuffle() }
            )
            MusicToggleButton(
                systemName: repeatIconName,
                isActive: musicService.info.repeatMode != 0,
                action: { musicService.cycleRepeat() }
            )
        }
    }

    private var musicPlaybackControls: some View {
        HStack(spacing: 24) {
            PlaybackButton(systemName: "backward.fill", size: 18) {
                musicService.previousTrack()
            }
            PlaybackButton(systemName: musicService.info.isPlaying ? "pause.fill" : "play.fill", size: 32, isPrimary: true) {
                musicService.togglePlay()
            }
            PlaybackButton(systemName: "forward.fill", size: 18) {
                musicService.nextTrack()
            }
        }
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
            .environmentObject(monitorService)
    }

    // MARK: - Stock Tab

    private var stockTab: some View {
        StockListView()
            .environmentObject(stockStore)
            .environmentObject(stockService)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private func formatDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: loc.currentLanguage.rawValue)
        return formatter.string(from: Date())
    }
}
