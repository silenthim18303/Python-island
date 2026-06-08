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
    let voice: VoiceService

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
        self.voice = VoiceService()

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
        }
    }

    // MARK: - Voice Command Handler

    private func handleVoiceCommand(_ command: VoiceCommand, text: String) {
        switch command {
        case .play:
            music.togglePlay()
            voice.speak("正在播放")
        case .pause:
            music.togglePlay()
            voice.speak("已暂停")
        case .next:
            music.nextTrack()
            voice.speak("下一首")
        case .previous:
            music.previousTrack()
            voice.speak("上一首")
        case .expand:
            IslandWindowManager.shared.show()
            NotificationCenter.default.post(name: .openIslandSettings, object: nil)
            voice.speak("已展开")
        case .collapse:
            IslandWindowManager.shared.collapse()
            voice.speak("已收起")
        case .show:
            IslandWindowManager.shared.show()
            voice.speak("已显示")
        case .hide:
            IslandWindowManager.shared.hide()
            voice.speak("已隐藏")
        case .weather:
            voice.speak("正在获取天气信息")
            Task { await weather.fetchWeather() }
        case .timer:
            let remaining = timer.pomodoro.remaining
            if timer.pomodoro.running && remaining > 0 {
                let minutes = remaining / 60
                voice.speak("番茄钟还剩\(minutes)分钟")
            } else {
                voice.speak("计时器空闲中")
            }
        case .todo:
            voice.speak("待办功能开发中")
        case .help:
            voice.speak("您可以说：播放、暂停、下一首、展开、收起、天气、计时器等指令")
        }
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
        voice.stopListening()
        voice.stopSpeaking()
    }
}
