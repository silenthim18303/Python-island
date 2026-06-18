//
//  WidgetDataManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/6.
//

import Foundation
import WidgetKit

/// 小组件数据管理器 — 将主 app 数据写入共享 JSON 文件，供 WidgetKit 读取
@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    /// App Group 共享容器路径
    private let containerURL: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.geminimortal.MacIsland"
    )
    private var dataFileURL: URL? {
        containerURL?.appendingPathComponent("widget_data.json")
    }

    /// 内存缓存
    private var cache: [String: Any] = [:]

    private init() {
        if let url = dataFileURL, let data = try? Data(contentsOf: url),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            cache = dict
        }
    }

    // MARK: - Helpers

    private func set(_ key: String, _ value: Any) {
        cache[key] = value
    }

    private func flush(_ kind: String) {
        guard let url = dataFileURL else { return }
        if let data = try? JSONSerialization.data(withJSONObject: cache, options: []) {
            try? data.write(to: url, options: .atomic)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }

    func reloadAllWidgets() {
        guard let url = dataFileURL else { return }
        if let data = try? JSONSerialization.data(withJSONObject: cache, options: []) {
            try? data.write(to: url, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Weather

    func updateWeather(
        temperature: Double,
        temperatureMax: Double,
        temperatureMin: Double,
        description: String,
        iconSystemName: String,
        humidity: Int,
        windSpeed: Double,
        cityName: String,
        districtName: String
    ) {
        set("widget_weather_hasData", true)
        set("widget_weather_temperature", temperature)
        set("widget_weather_temperature_max", temperatureMax)
        set("widget_weather_temperature_min", temperatureMin)
        set("widget_weather_description", description)
        set("widget_weather_icon", iconSystemName)
        set("widget_weather_humidity", humidity)
        set("widget_weather_windSpeed", windSpeed)
        set("widget_weather_city", cityName)
        set("widget_weather_district", districtName)
        set("widget_weather_updated_at", Date().timeIntervalSince1970)
        flush("WeatherWidget")
    }

    // MARK: - Timer

    func updateTimer(
        type: String,
        remainingSeconds: Int,
        totalSeconds: Int,
        isRunning: Bool,
        completedPomodoros: Int,
        currentPhase: String,
        state: String
    ) {
        let now = Date()
        let clampedRemaining = max(remainingSeconds, 0)
        set("widget_timer_type", type)
        set("widget_timer_remaining", clampedRemaining)
        set("widget_timer_total", max(totalSeconds, 0))
        set("widget_timer_running", isRunning)
        set("widget_timer_pomodoros", completedPomodoros)
        set("widget_timer_phase", currentPhase)
        set("widget_timer_state", state)
        set("widget_timer_updated_at", now.timeIntervalSince1970)
        set("widget_timer_target_at", isRunning ? now.addingTimeInterval(TimeInterval(clampedRemaining)).timeIntervalSince1970 : 0)
        flush("TimerWidget")
    }

    // MARK: - System Monitor

    func updateSystemMonitor(
        cpuUsage: Double, cpuTemperature: Double, cpuCoreCount: Int,
        memoryUsage: Double, memoryUsed: Double, memoryTotal: Double,
        diskUsage: Double, diskUsed: Double, diskTotal: Double,
        batteryLevel: Int, batteryCharging: Bool,
        networkConnected: Bool, networkType: String, localIP: String,
        uploadSpeed: Double, downloadSpeed: Double
    ) {
        set("widget_cpu_usage", cpuUsage)
        set("widget_cpu_temperature", cpuTemperature)
        set("widget_cpu_cores", cpuCoreCount)
        set("widget_memory_usage", memoryUsage)
        set("widget_memory_used", memoryUsed)
        set("widget_memory_total", memoryTotal)
        set("widget_disk_usage", diskUsage)
        set("widget_disk_used", diskUsed)
        set("widget_disk_total", diskTotal)
        set("widget_battery_level", batteryLevel)
        set("widget_battery_charging", batteryCharging)
        set("widget_network_connected", networkConnected)
        set("widget_network_type", networkType)
        set("widget_network_ip", localIP)
        set("widget_network_upload", uploadSpeed)
        set("widget_network_download", downloadSpeed)
        set("widget_system_updated_at", Date().timeIntervalSince1970)
        flush("SystemMonitorWidget")
    }

    // MARK: - Todo

    func updateTodo(totalCount: Int, completedCount: Int, items: [[String: Any]]) {
        set("widget_todo_total", totalCount)
        set("widget_todo_completed", completedCount)
        set("widget_todo_updated_at", Date().timeIntervalSince1970)
        set("widget_todo_items", items)
        flush("TodoWidget")
    }

    // MARK: - Clipboard

    func updateClipboard(items: [[String: Any]]) {
        set("widget_clipboard_updated_at", Date().timeIntervalSince1970)
        set("widget_clipboard_items", items)
        flush("ClipboardWidget")
    }

    // MARK: - Events

    func updateEvents(items: [[String: Any]]) {
        set("widget_event_updated_at", Date().timeIntervalSince1970)
        set("widget_event_items", items)
        flush("EventWidget")
    }

    // MARK: - Stocks

    func updateStocks(items: [[String: Any]]) {
        set("widget_stock_updated_at", Date().timeIntervalSince1970)
        set("widget_stock_items", items)
        flush("StockWidget")
    }
}
