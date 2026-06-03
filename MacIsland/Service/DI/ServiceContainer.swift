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

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        weatherConfig: QWeatherConfig? = nil,
        mediaKeySender: MediaKeySenderProtocol? = nil,
        systemMonitor: SystemMonitorProtocol? = nil
    ) {
        self.weather = QWeatherService(config: weatherConfig ?? .autoDetect(locationID: "101010100"))
        self.music = SystemMusicService(mediaKeySender: mediaKeySender ?? DefaultMediaKeySender())
        self.monitor = SystemMonitorServiceImpl(monitor: systemMonitor ?? DefaultSystemMonitor())
        self.lyrics = LyricsService()
        self.timer = TimerService()
        self.clipboard = ClipboardService()
        self.hotkey = HotkeyService()

        // Wire hotkey callbacks
        self.hotkey.onToggleIsland = { IslandWindowManager.shared.toggle() }
        self.hotkey.onPlayPause = { [weak self] in self?.music.togglePlay() }
        self.hotkey.onNextTrack = { [weak self] in self?.music.nextTrack() }
        self.hotkey.onPreviousTrack = { [weak self] in self?.music.previousTrack() }

        // 剪贴板配置 — 以 AppSettings 为单一数据源，初始化并订阅变化同步给服务
        let settings = AppSettings.shared
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
    }

    // MARK: - Lifecycle

    func startAll() {
        music.startMonitoring()
        monitor.startMonitoring()
        clipboard.startMonitoring()
        hotkey.startMonitoring()
        Task { await weather.fetchWeather() }
    }

    func stopAll() {
        music.stopMonitoring()
        monitor.stopMonitoring()
        clipboard.stopMonitoring()
        hotkey.stopMonitoring()
    }
}
