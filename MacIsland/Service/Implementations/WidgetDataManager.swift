//
//  WidgetDataManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/6.
//

import Foundation
import WidgetKit
import Combine

/// 小组件数据管理器 — 将主 app 数据写入 UserDefaults，供 WidgetKit 读取
@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    /// 使用 App Group 共享 UserDefaults，主 app 和小组件都能访问
    private let defaults = UserDefaults(suiteName: "group.geminimortal.MacIsland") ?? UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Weather

    func updateWeather(temperature: Double, description: String, iconSystemName: String, humidity: Int, windSpeed: Double) {
        defaults.set(temperature, forKey: "widget_weather_temperature")
        defaults.set(description, forKey: "widget_weather_description")
        defaults.set(iconSystemName, forKey: "widget_weather_icon")
        defaults.set(humidity, forKey: "widget_weather_humidity")
        defaults.set(windSpeed, forKey: "widget_weather_windSpeed")

        reloadWeatherWidget()
    }

    // MARK: - Music

    func updateMusic(hasMedia: Bool, title: String, artist: String, isPlaying: Bool, progress: Double) {
        defaults.set(hasMedia, forKey: "widget_music_hasMedia")
        defaults.set(title, forKey: "widget_music_title")
        defaults.set(artist, forKey: "widget_music_artist")
        defaults.set(isPlaying, forKey: "widget_music_isPlaying")
        defaults.set(progress, forKey: "widget_music_progress")

        reloadMusicWidget()
    }

    // MARK: - Timer

    func updateTimer(type: String, remainingSeconds: Int, isRunning: Bool, completedPomodoros: Int) {
        defaults.set(type, forKey: "widget_timer_type")
        defaults.set(remainingSeconds, forKey: "widget_timer_remaining")
        defaults.set(isRunning, forKey: "widget_timer_running")
        defaults.set(completedPomodoros, forKey: "widget_timer_pomodoros")

        reloadTimerWidget()
    }

    // MARK: - Widget Reload

    private func reloadWeatherWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "WeatherWidget")
    }

    private func reloadMusicWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
    }

    private func reloadTimerWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "TimerWidget")
    }

    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
