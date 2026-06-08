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
    func placeholder(in context: Context) -> SystemMonitorEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (SystemMonitorEntry) -> Void) { completion(.placeholder) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemMonitorEntry>) -> Void) {
        let entry = SystemMonitorEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
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
    let networkConnected: Bool
    let networkType: String
    let localIP: String
    let uploadSpeed: Double
    let downloadSpeed: Double
    let updatedAt: Date?

    static var placeholder: SystemMonitorEntry {
        SystemMonitorEntry(
            date: Date(), cpuUsage: 35, cpuTemperature: 52, cpuCoreCount: 8,
            memoryUsage: 62, memoryUsed: 10.2, memoryTotal: 16.0,
            diskUsage: 45, diskUsed: 220, diskTotal: 500,
            batteryLevel: 78, batteryCharging: true,
            networkConnected: true, networkType: "Wi-Fi", localIP: "192.168.1.8",
            uploadSpeed: 1250000, downloadSpeed: 5800000, updatedAt: Date()
        )
    }

    static func fromUserDefaults() -> SystemMonitorEntry {
        let ts = WidgetConstants.double("widget_system_updated_at")
        return SystemMonitorEntry(
            date: Date(),
            cpuUsage: WidgetConstants.double("widget_cpu_usage"),
            cpuTemperature: WidgetConstants.double("widget_cpu_temperature"),
            cpuCoreCount: WidgetConstants.int("widget_cpu_cores"),
            memoryUsage: WidgetConstants.double("widget_memory_usage"),
            memoryUsed: WidgetConstants.double("widget_memory_used"),
            memoryTotal: WidgetConstants.double("widget_memory_total"),
            diskUsage: WidgetConstants.double("widget_disk_usage"),
            diskUsed: WidgetConstants.double("widget_disk_used"),
            diskTotal: WidgetConstants.double("widget_disk_total"),
            batteryLevel: WidgetConstants.int("widget_battery_level"),
            batteryCharging: WidgetConstants.bool("widget_battery_charging"),
            networkConnected: WidgetConstants.bool("widget_network_connected"),
            networkType: WidgetConstants.string("widget_network_type") ?? "",
            localIP: WidgetConstants.string("widget_network_ip") ?? "",
            uploadSpeed: WidgetConstants.double("widget_network_upload"),
            downloadSpeed: WidgetConstants.double("widget_network_download"),
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        )
    }

    var hasData: Bool { cpuCoreCount > 0 || memoryTotal > 0 || diskTotal > 0 }
    var cpuString: String { WidgetFormat.percent(cpuUsage) }
    var memoryString: String { WidgetFormat.percent(memoryUsage) }
    var diskString: String { WidgetFormat.percent(diskUsage) }
    var batteryString: String { "\(batteryLevel)%" }
    var temperatureString: String { cpuTemperature > 0 ? "\(Int(cpuTemperature))°C" : "--" }
    var updateString: String { WidgetFormat.relativeTime(updatedAt) }
    var networkTitle: String {
        guard networkConnected else { return WidgetL10n.monitorOffline }
        return networkType.isEmpty ? WidgetL10n.monitorOnline : networkType
    }

    var cpuColor: Color { cpuUsage > 80 ? .red : cpuUsage > 60 ? .orange : .green }
    var memoryColor: Color { memoryUsage > 80 ? .red : memoryUsage > 60 ? .orange : .blue }
    var diskColor: Color { diskUsage > 90 ? .red : diskUsage > 70 ? .orange : .purple }
    var batteryColor: Color { batteryLevel <= 20 ? .red : batteryLevel <= 50 ? .orange : (batteryCharging ? .green : .primary) }

    var batteryIcon: String {
        if batteryCharging { return "battery.100.bolt" }
        if batteryLevel <= 10 { return "battery.0" }
        if batteryLevel <= 25 { return "battery.25" }
        if batteryLevel <= 50 { return "battery.50" }
        if batteryLevel <= 75 { return "battery.75" }
        return "battery.100"
    }

    func formatSpeed(_ bytesPerSec: Double) -> String { WidgetFormat.speed(bytesPerSec) }
}

// MARK: - System Monitor Widget

struct SystemMonitorWidget: Widget {
    let kind = "SystemMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMonitorTimelineProvider()) { entry in
            SystemMonitorWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName(WidgetL10n.monitorDisplayName)
        .description(WidgetL10n.monitorDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        case .systemLarge: largeView
        default: smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.hasData {
                WidgetHeader(icon: "cpu", title: WidgetL10n.monitorSystem, trailing: entry.updateString, color: .green)

                MonitorRow(icon: "cpu", label: "CPU", value: entry.cpuString,
                           detail: entry.temperatureString, color: entry.cpuColor)
                MonitorRow(icon: "memorychip", label: "内存", value: entry.memoryString,
                           detail: String(format: "%.1fG", entry.memoryUsed), color: entry.memoryColor)

                HStack(spacing: 8) {
                    CompactStatus(icon: entry.batteryIcon, value: entry.batteryString, color: entry.batteryColor)
                    Spacer(minLength: 4)
                    CompactStatus(icon: entry.networkConnected ? "arrow.down" : "wifi.slash",
                                  value: entry.networkConnected ? entry.formatSpeed(entry.downloadSpeed) : WidgetL10n.monitorOffline,
                                  color: entry.networkConnected ? .cyan : .secondary)
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "cpu", message: WidgetL10n.monitorSyncHint)
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.hasData {
                WidgetHeader(icon: "desktopcomputer", title: WidgetL10n.monitorDisplayName, trailing: entry.updateString, color: .green)

                HStack(spacing: 12) {
                    // 左侧：3个进度条
                    VStack(spacing: 8) {
                        CompactGauge(label: "CPU", value: entry.cpuUsage / 100,
                                     detail: entry.temperatureString, color: entry.cpuColor)
                        CompactGauge(label: "RAM", value: entry.memoryUsage / 100,
                                     detail: String(format: "%.1fG", entry.memoryUsed), color: entry.memoryColor)
                        CompactGauge(label: "Disk", value: entry.diskUsage / 100,
                                     detail: String(format: "%.0fG", entry.diskUsed), color: entry.diskColor)
                    }
                    .frame(width: 100)

                    // 右侧：状态卡片
                    VStack(spacing: 6) {
                        // 电池 + 网络状态
                        HStack(spacing: 8) {
                            StatusBadge(icon: entry.batteryIcon, value: entry.batteryString, color: entry.batteryColor)
                            StatusBadge(icon: entry.networkConnected ? "wifi" : "wifi.slash",
                                        value: entry.networkConnected ? entry.networkType : WidgetL10n.monitorOffline,
                                        color: entry.networkConnected ? .cyan : .secondary)
                        }

                        // 网络速度
                        HStack(spacing: 8) {
                            SpeedCard(direction: "↓", speed: entry.formatSpeed(entry.downloadSpeed), color: .cyan)
                            SpeedCard(direction: "↑", speed: entry.formatSpeed(entry.uploadSpeed), color: .blue)
                        }
                    }
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "desktopcomputer", message: WidgetL10n.monitorOpenHint)
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entry.hasData {
                WidgetHeader(icon: "desktopcomputer", title: WidgetL10n.monitorDisplayName, trailing: entry.updateString, color: .green)

                // CPU 和内存仪表盘
                HStack(spacing: 16) {
                    CircularGauge(value: entry.cpuUsage / 100, label: WidgetL10n.monitorCPU, detail: entry.temperatureString, color: entry.cpuColor)
                    CircularGauge(value: entry.memoryUsage / 100, label: WidgetL10n.monitorMemory,
                                  detail: String(format: "%.1fG/%.0fG", entry.memoryUsed, entry.memoryTotal), color: entry.memoryColor)
                    CircularGauge(value: entry.diskUsage / 100, label: WidgetL10n.monitorDisk,
                                  detail: String(format: "%.0fG/%.0fG", entry.diskUsed, entry.diskTotal), color: entry.diskColor)
                }

                Divider()

                // 详细信息网格
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 8) {
                    SystemDetailCard(icon: entry.batteryIcon, title: WidgetL10n.monitorBattery, value: entry.batteryString,
                                     subtitle: entry.batteryCharging ? WidgetL10n.monitorCharging : WidgetL10n.monitorDischarging, color: entry.batteryColor)
                    SystemDetailCard(icon: entry.networkConnected ? "wifi" : "wifi.slash", title: WidgetL10n.monitorNetwork,
                                     value: entry.networkTitle, subtitle: entry.localIP, color: entry.networkConnected ? .cyan : .secondary)
                    SystemDetailCard(icon: "arrow.down", title: WidgetL10n.monitorDownload,
                                     value: entry.formatSpeed(entry.downloadSpeed), subtitle: "", color: .cyan)
                    SystemDetailCard(icon: "arrow.up", title: WidgetL10n.monitorUpload,
                                     value: entry.formatSpeed(entry.uploadSpeed), subtitle: "", color: .blue)
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "desktopcomputer", message: WidgetL10n.monitorOpenHint)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Circular Gauge

private struct CircularGauge: View {
    let value: Double
    let label: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - System Detail Card

private struct SystemDetailCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}

// MARK: - Monitor Components

private struct MonitorRow: View {
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

private struct CompactStatus: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
            WidgetProgressBar(value: value, color: color, height: 4)
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Compact Gauge (for Medium widget)

private struct CompactGauge: View {
    let label: String
    let value: Double
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)

            VStack(spacing: 3) {
                WidgetProgressBar(value: value, color: color, height: 5)

                HStack {
                    Text(String(format: "%.0f%%", value * 100))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(detail)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Status Badge (for Medium widget)

private struct StatusBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
    }
}

// MARK: - Speed Card (for Medium widget)

private struct SpeedCard: View {
    let direction: String
    let speed: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(direction)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
            Text(speed)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
    }
}
