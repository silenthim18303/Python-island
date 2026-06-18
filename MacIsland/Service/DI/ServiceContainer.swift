//
//  ServiceContainer.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine

// MARK: - Service Container

/// 依赖注入容器
@MainActor
final class ServiceContainer {
    // MARK: - Services

    let weather: QWeatherService
    let monitor: SystemMonitorServiceImpl
    let timer: TimerService
    let clipboard: ClipboardService
    let hotkey: HotkeyService
    let voice: VoiceService
    let stocks: StockServiceImpl
    let music: MusicService
    let lyrics: LyricsService

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        weatherConfig: QWeatherConfig? = nil,
        systemMonitor: SystemMonitorProtocol? = nil
    ) {
        let settings = AppSettings.shared

        // 天气配置：优先手动城市 > 默认自动定位
        let weatherCfg: QWeatherConfig
        if !settings.weatherManualCity.isEmpty && !settings.weatherManualLocationID.isEmpty {
            weatherCfg = .fixed(
                apiKey: settings.weatherEffectiveAPIKey,
                apiHost: settings.weatherEffectiveAPIHost,
                locationID: settings.weatherManualLocationID,
                cityName: settings.weatherManualCity,
                districtName: ""
            )
        } else {
            weatherCfg = weatherConfig ?? .autoDetect(apiKey: settings.weatherEffectiveAPIKey, apiHost: settings.weatherEffectiveAPIHost, locationID: "101010100")
        }
        self.weather = QWeatherService(config: weatherCfg)
        self.monitor = SystemMonitorServiceImpl(monitor: systemMonitor ?? DefaultSystemMonitor())
        self.timer = TimerService()
        self.clipboard = ClipboardService()
        self.hotkey = HotkeyService()
        self.voice = VoiceService()
        self.stocks = StockServiceImpl()
        self.music = MusicService()
        self.lyrics = LyricsService()

        // Wire voice command callbacks
        self.voice.onCommand = { [weak self] command, text in
            Task { @MainActor in
                self?.handleVoiceCommand(command, text: text)
            }
        }

        // Wire hotkey callbacks
        self.hotkey.onToggleIsland = { IslandWindowManager.shared.toggle() }
        self.hotkey.onPlayPause = { [weak self] in self?.music.togglePlay() }
        self.hotkey.onNextTrack = { [weak self] in self?.music.nextTrack() }
        self.hotkey.onPreviousTrack = { [weak self] in self?.music.previousTrack() }

        // 剪贴板配置 — 以 AppSettings 为单一数据源，初始化并订阅变化同步给服务
        self.clipboard.isEnabled = settings.clipboardEnabled
        self.clipboard.urlDetectMode = settings.clipboardUrlDetectMode
        self.clipboard.blacklistedDomains = settings.blacklistedDomains
        settings.$clipboardEnabled
            .sink { [weak self] in self?.clipboard.isEnabled = $0 }
            .store(in: &cancellables)
        settings.$clipboardUrlDetectMode
            .sink { [weak self] in self?.clipboard.urlDetectMode = $0 }
            .store(in: &cancellables)
        settings.$blacklistedDomains
            .sink { [weak self] in self?.clipboard.blacklistedDomains = $0 }
            .store(in: &cancellables)

        if weatherConfig == nil {
            settings.$weatherAPIKey
                .sink { [weak self, weak settings] _ in
                    guard let settings else { return }
                    self?.weather.updateAPIKey(settings.weatherEffectiveAPIKey)
                }
                .store(in: &cancellables)
            settings.$weatherAPIHost
                .sink { [weak self, weak settings] _ in
                    guard let settings else { return }
                    self?.weather.updateAPIHost(settings.weatherEffectiveAPIHost)
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Voice Command Handler

    private func handleVoiceCommand(_ command: VoiceCommand, text: String) {
        switch command {
        case .expand:
            IslandWindowManager.shared.show()
            NotificationCenter.default.post(name: .openIslandSettings, object: nil)
            voice.speak(L10n.voiceResponseExpanded)
        case .collapse:
            IslandWindowManager.shared.collapse()
            voice.speak(L10n.voiceResponseCollapsed)
        case .show:
            IslandWindowManager.shared.show()
            voice.speak(L10n.voiceResponseShown)
        case .hide:
            IslandWindowManager.shared.hide()
            voice.speak(L10n.voiceResponseHidden)
        case .weather:
            voice.speak(L10n.voiceResponseFetchingWeather)
            Task { await weather.fetchWeather() }
        case .timer:
            let remaining = timer.pomodoro.remaining
            if timer.pomodoro.running && remaining > 0 {
                let minutes = remaining / 60
                voice.speak(L10n.voiceResponseTimerRemaining(minutes: minutes))
            } else {
                voice.speak(L10n.voiceResponseTimerIdle)
            }
        case .todo:
            voice.speak(L10n.voiceResponseTodoDev)
        case .help:
            voice.speak(L10n.voiceResponseHelp)
        case .stock:
            voice.speak("股票功能开发中")
        case .play:
            music.togglePlay()
            voice.speak(L10n.voiceResponsePlaying)
        case .pause:
            music.togglePlay()
            voice.speak(L10n.voiceResponsePaused)
        case .next:
            music.nextTrack()
            voice.speak(L10n.voiceResponseNext)
        case .previous:
            music.previousTrack()
            voice.speak(L10n.voiceResponsePrevious)
        }
    }

    // MARK: - Lifecycle

    func startAll() {
        monitor.startMonitoring()
        clipboard.startMonitoring()
        hotkey.startMonitoring()
        music.startMonitoring()
        Task { await weather.fetchWeather() }

        // 恢复股票自动刷新 & 初始行情获取
        let settings = AppSettings.shared
        let store = StockStore.shared

        if !store.watchlist.isEmpty {
            Task { await store.refreshAllQuotes() }
        }
        if settings.stockAutoRefresh {
            store.startAutoRefresh(interval: TimeInterval(settings.stockRefreshInterval))
        }
    }

    func stopAll() {
        monitor.stopMonitoring()
        clipboard.stopMonitoring()
        hotkey.stopMonitoring()
        music.stopMonitoring()
        voice.stopListening()
        voice.stopSpeaking()
    }
}
