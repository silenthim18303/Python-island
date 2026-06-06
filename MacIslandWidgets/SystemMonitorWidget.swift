//
//  SystemMonitorWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - System Monitor Timeline Provider

struct SystemMonitorTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SystemMonitorEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemMonitorEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemMonitorEntry>) -> Void) {
        let entry = SystemMonitorEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - System Monitor Entry

struct SystemMonitorEntry: TimelineEntry {
    let date: Date
    let cpuUsage: Double
    let cpuTemperature: Double
    let cpuCoreCount: Int
    let memoryUsage: Double
    let memoryUsed: Double
    let memoryTotal: Double
    let diskUsage: Double
    let diskUsed: Double
    let diskTotal: Double
    let batteryLevel: Int
    let batteryCharging: Bool

    static var placeholder: SystemMonitorEntry {
        SystemMonitorEntry(
            date: Date(),
            cpuUsage: 35,
            cpuTemperature: 52,
            cpuCoreCount: 8,
            memoryUsage: 62,
            memoryUsed: 10.2,
            memoryTotal: 16.0,
            diskUsage: 45,
            diskUsed: 220,
            diskTotal: 500,
            batteryLevel: 78,
            batteryCharging: true
        )
    }

    static func fromUserDefaults() -> SystemMonitorEntry {
        let d = WidgetConstants.sharedDefaults
        return SystemMonitorEntry(
            date: Date(),
            cpuUsage: d.double(forKey: "widget_cpu_usage"),
            cpuTemperature: d.double(forKey: "widget_cpu_temperature"),
            cpuCoreCount: d.integer(forKey: "widget_cpu_cores"),
            memoryUsage: d.double(forKey: "widget_memory_usage"),
            memoryUsed: d.double(forKey: "widget_memory_used"),
            memoryTotal: d.double(forKey: "widget_memory_total"),
            diskUsage: d.double(forKey: "widget_disk_usage"),
            diskUsed: d.double(forKey: "widget_disk_used"),
            diskTotal: d.double(forKey: "widget_disk_total"),
            batteryLevel: d.integer(forKey: "widget_battery_level"),
            batteryCharging: d.bool(forKey: "widget_battery_charging")
        )
    }

    var cpuString: String { String(format: "%.0f%%", cpuUsage) }
    var memoryString: String { String(format: "%.0f%%", memoryUsage) }
    var diskString: String { String(format: "%.0f%%", diskUsage) }
    var batteryString: String { "\(batteryLevel)%" }
    var temperatureString: String { "\(Int(cpuTemperature))°C" }
}

// MARK: - System Monitor Widget

struct SystemMonitorWidget: Widget {
    let kind = "SystemMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorTimelineProvider()) { entry in
            SystemMonitorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("系统监控")
        .description("CPU、内存、磁盘、电池状态")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - System Monitor Widget View

struct SystemMonitorWidgetView: View {
    let entry: SystemMonitorEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 10) {
            // CPU
            MonitorItem(icon: "cpu", label: "CPU", value: entry.cpuString,
                       detail: entry.temperatureString, color: cpuColor)

            // Memory
            MonitorItem(icon: "memorychip", label: "RAM", value: entry.memoryString,
                       detail: String(format: "%.1fG/%.0fG", entry.memoryUsed, entry.memoryTotal), color: memoryColor)

            // Battery
            HStack(spacing: 6) {
                Image(systemName: batteryIcon)
                    .font(.system(size: 11))
                    .foregroundColor(batteryColor)
                Text(entry.batteryString)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                if entry.batteryCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：CPU + 内存
            VStack(spacing: 12) {
                MonitorGauge(label: "CPU", value: entry.cpuUsage / 100,
                            detail: entry.temperatureString, color: cpuColor)
                MonitorGauge(label: "RAM", value: entry.memoryUsage / 100,
                            detail: String(format: "%.1fG", entry.memoryUsed), color: memoryColor)
            }
            .frame(width: 80)

            Divider()

            // 右侧：磁盘 + 电池
            VStack(spacing: 12) {
                MonitorGauge(label: "Disk", value: entry.diskUsage / 100,
                            detail: String(format: "%.0fG", entry.diskUsed), color: diskColor)

                HStack(spacing: 8) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 14))
                        .foregroundColor(batteryColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.batteryString)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Text(entry.batteryCharging ? "Charging" : "On Battery")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var cpuColor: Color {
        if entry.cpuUsage > 80 { return .red }
        if entry.cpuUsage > 60 { return .orange }
        return .green
    }

    private var memoryColor: Color {
        if entry.memoryUsage > 80 { return .red }
        if entry.memoryUsage > 60 { return .orange }
        return .blue
    }

    private var diskColor: Color {
        if entry.diskUsage > 90 { return .red }
        if entry.diskUsage > 70 { return .orange }
        return .purple
    }

    private var batteryColor: Color {
        if entry.batteryLevel <= 20 { return .red }
        if entry.batteryLevel <= 50 { return .orange }
        return entry.batteryCharging ? .green : .primary
    }

    private var batteryIcon: String {
        if entry.batteryCharging { return "battery.100.bolt" }
        if entry.batteryLevel <= 10 { return "battery.0" }
        if entry.batteryLevel <= 25 { return "battery.25" }
        if entry.batteryLevel <= 50 { return "battery.50" }
        if entry.batteryLevel <= 75 { return "battery.75" }
        return "battery.100"
    }
}

// MARK: - Monitor Components

private struct MonitorItem: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 36, alignment: .trailing)

            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

private struct MonitorGauge: View {
    let label: String
    let value: Double
    let detail: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(value, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
