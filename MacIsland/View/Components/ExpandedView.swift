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
    @EnvironmentObject var monitorService: SystemMonitorServiceImpl
    @EnvironmentObject var stockStore: StockStore
    @EnvironmentObject var stockService: StockServiceImpl
    @EnvironmentObject var musicService: MusicService
    @EnvironmentObject var lyricsService: LyricsService

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
            case .music: return L10n.tabMusic
            case .tools: return L10n.tabToolbox
            case .monitor: return L10n.monitorTitle
            case .stock: return L10n.stockTitle
            }
        }

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .music: return "waveform"
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
        .onChange(of: store.expandedInitialTab) { _, tabName in
            if let tabName,
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
            sliderSection

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

    // MARK: - Slider Section (Volume + Brightness)

    @State private var volume: Double = Double(SystemControl.shared.getVolume())
    @State private var brightness: Double = Double(SystemControl.shared.getBrightness())

    private var sliderSection: some View {
        HStack(spacing: 12) {
            systemSlider(
                icon: volume > 0.5 ? "speaker.wave.3.fill" : (volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill"),
                value: $volume,
                color: .cyan
            ) { val in
                SystemControl.shared.setVolume(Float(val))
            }

            systemSlider(
                icon: "sun.max.fill",
                value: $brightness,
                color: .yellow
            ) { val in
                SystemControl.shared.setBrightness(Float(val))
            }
        }
    }

    private func systemSlider(icon: String, value: Binding<Double>, color: Color, onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 14)

            Slider(value: value, in: 0...1)
                .tint(color)
                .onChange(of: value.wrappedValue) { _, newVal in
                    onChange(newVal)
                }

            Text("\(Int(value.wrappedValue * 100))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 26, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
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

    // MARK: - Music Tab

    private var musicTab: some View {
        VStack(spacing: 12) {
            // 播放信息
            if musicService.hasMedia {
                musicInfoSection
                musicProgressSection
                musicControlSection
                musicLyricsSection
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.3))
                    Text(L10n.musicNoPlayback)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var musicInfoSection: some View {
        HStack(spacing: 12) {
            // 封面
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(musicService.info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(musicService.info.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                if !musicService.info.album.isEmpty {
                    Text(musicService.info.album)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    private var musicProgressSection: some View {
        VStack(spacing: 4) {
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.6))
                        .frame(width: geo.size.width * musicService.info.progress, height: 3)
                }
            }
            .frame(height: 3)

            // 时间
            HStack {
                Text(musicService.info.formattedElapsed)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(musicService.info.formattedDuration)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var musicControlSection: some View {
        HStack(spacing: 24) {
            Button { musicService.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Button { musicService.togglePlay() } label: {
                Image(systemName: musicService.info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button { musicService.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var musicLyricsSection: some View {
        Group {
            if !lyricsService.currentLyrics.lines.isEmpty,
               let activeIndex = lyricsService.currentLyrics.activeLineIndex(at: musicService.info.elapsedTime) {
                VStack(spacing: 6) {
                    if activeIndex > 0 {
                        Text(lyricsService.currentLyrics.lines[activeIndex - 1].text)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }

                    Text(lyricsService.currentLyrics.lines[activeIndex].text)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)

                    if activeIndex + 1 < lyricsService.currentLyrics.lines.count {
                        Text(lyricsService.currentLyrics.lines[activeIndex + 1].text)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
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
