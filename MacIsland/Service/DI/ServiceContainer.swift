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
    let music: SystemMusicService
    let monitor: SystemMonitorServiceImpl
    let lyrics: LyricsService
    let timer: TimerService
    let clipboard: ClipboardService
    let hotkey: HotkeyService
    let phone: PhoneServiceImpl

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        weatherConfig: QWeatherConfig? = nil,
        mediaKeySender: MediaKeySenderProtocol? = nil,
        systemMonitor: SystemMonitorProtocol? = nil
    ) {
        let settings = AppSettings.shared

        // 天气配置：优先手动城市 > 默认自动定位
        let weatherCfg: QWeatherConfig
        if !settings.weatherManualCity.isEmpty && !settings.weatherManualLocationID.isEmpty {
            weatherCfg = .fixed(
                apiKey: settings.weatherEffectiveAPIKey,
                locationID: settings.weatherManualLocationID,
                cityName: settings.weatherManualCity,
                districtName: ""
            )
        } else {
            weatherCfg = weatherConfig ?? .autoDetect(apiKey: settings.weatherEffectiveAPIKey, locationID: "101010100")
        }
        self.weather = QWeatherService(config: weatherCfg)
        self.music = SystemMusicService(mediaKeySender: mediaKeySender ?? DefaultMediaKeySender())
        self.monitor = SystemMonitorServiceImpl(monitor: systemMonitor ?? DefaultSystemMonitor())
        self.lyrics = LyricsService()
        self.timer = TimerService()
        self.clipboard = ClipboardService()
        self.hotkey = HotkeyService()
        self.phone = PhoneServiceImpl()

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
        }
    }

    // MARK: - Lifecycle

    func startAll() {
        music.startMonitoring()
        monitor.startMonitoring()
        clipboard.startMonitoring()
        hotkey.startMonitoring()
        Task { await weather.fetchWeather() }

        // 手机配对自动启动
        if AppSettings.shared.phoneAutoStart {
            phone.startListening()
        }
    }

    func stopAll() {
        music.stopMonitoring()
        monitor.stopMonitoring()
        clipboard.stopMonitoring()
        hotkey.stopMonitoring()
        phone.stopListening()
    }
}
