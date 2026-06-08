//
//  WidgetShared.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import SwiftUI
import WidgetKit

// MARK: - Shared Constants

enum WidgetConstants {
    static let appGroupID = "group.geminimortal.MacIsland"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }

    /// 从 App Group 容器的 JSON 文件读取数据
    private static var cachedData: [String: Any]?

    static func readData() -> [String: Any] {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return [:]
        }
        let fileURL = container.appendingPathComponent("widget_data.json")
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback: try reading from UserDefaults
            let d = sharedDefaults
            var fallback: [String: Any] = [:]
            for key in ["widget_weather_hasData", "widget_weather_temperature", "widget_weather_description",
                         "widget_weather_icon", "widget_weather_humidity", "widget_weather_windSpeed",
                         "widget_weather_city", "widget_weather_district", "widget_weather_updated_at",
                         "widget_weather_temperature_max", "widget_weather_temperature_min",
                         "widget_cpu_usage", "widget_cpu_temperature", "widget_cpu_cores",
                         "widget_memory_usage", "widget_memory_used", "widget_memory_total",
                         "widget_disk_usage", "widget_disk_used", "widget_disk_total",
                         "widget_battery_level", "widget_battery_charging",
                         "widget_network_connected", "widget_network_type", "widget_network_ip",
                         "widget_network_upload", "widget_network_download",
                         "widget_system_updated_at"] {
                let val = d.object(forKey: key)
                if val != nil { fallback[key] = val }
            }
            return fallback
        }
        return dict
    }

    static func bool(_ key: String) -> Bool {
        readData()[key] as? Bool ?? false
    }

    static func int(_ key: String) -> Int {
        readData()[key] as? Int ?? 0
    }

    static func double(_ key: String) -> Double {
        readData()[key] as? Double ?? 0
    }

    static func string(_ key: String) -> String? {
        readData()[key] as? String
    }

    static func data(_ key: String) -> Data? {
        guard let arr = readData()[key] as? [[String: Any]] else { return nil }
        return try? JSONSerialization.data(withJSONObject: arr)
    }
}

// MARK: - Widget Theme

enum WidgetTheme {
    static let accentColor = Color.blue
    static let secondaryColor = Color.secondary
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 12
}

// MARK: - Widget Background

extension View {
    func macIslandWidgetBackground() -> some View {
        self
            .containerBackground(for: .widget) {
                Color("WidgetBackground")
            }
    }
}

// MARK: - Widget Format

enum WidgetFormat {
    static func date(from defaults: UserDefaults, key: String) -> Date? {
        let timestamp = defaults.double(forKey: key)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func relativeTime(_ date: Date?) -> String {
        guard let date else { return "未同步" }
        let seconds = max(Int(Date().timeIntervalSince(date)), 0)
        if seconds < 60 { return "刚刚" }
        if seconds < 3600 { return "\(seconds / 60)分钟前" }
        if seconds < 86_400 { return "\(seconds / 3600)小时前" }
        return "\(seconds / 86_400)天前"
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 { return String(format: "%.0fB/s", bytesPerSecond) }
        if bytesPerSecond < 1024 * 1024 { return String(format: "%.1fKB/s", bytesPerSecond / 1024) }
        return String(format: "%.1fMB/s", bytesPerSecond / 1024 / 1024)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }
}

// MARK: - Widget Header

struct WidgetHeader: View {
    let icon: String
    let title: String
    let trailing: String?
    let color: Color

    init(icon: String, title: String, trailing: String? = nil, color: Color = .accentColor) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Widget Progress Bar

struct WidgetProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(value, 0), 1), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Widget Key Value Row

struct WidgetInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .frame(width: 14)

            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - Widget Placeholder View

struct WidgetPlaceholderView: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Widget Empty State

struct WidgetEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}
