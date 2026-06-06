//
//  WeatherWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Weather Timeline Provider

struct WeatherTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(WeatherEntry.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        // 从 UserDefaults 读取天气数据
        let entry = WeatherEntry.fromUserDefaults()

        // 每 30 分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Weather Entry

struct WeatherEntry: TimelineEntry {
    let date: Date
    let temperature: Double
    let description: String
    let iconSystemName: String
    let humidity: Int
    let windSpeed: Double

    static var placeholder: WeatherEntry {
        WeatherEntry(
            date: Date(),
            temperature: 22,
            description: "晴",
            iconSystemName: "sun.max.fill",
            humidity: 45,
            windSpeed: 12
        )
    }

    static func fromUserDefaults() -> WeatherEntry {
        let defaults = UserDefaults.standard
        return WeatherEntry(
            date: Date(),
            temperature: defaults.double(forKey: "widget_weather_temperature"),
            description: defaults.string(forKey: "widget_weather_description") ?? "--",
            iconSystemName: defaults.string(forKey: "widget_weather_icon") ?? "cloud.fill",
            humidity: defaults.integer(forKey: "widget_weather_humidity"),
            windSpeed: defaults.double(forKey: "widget_weather_windSpeed")
        )
    }
}

// MARK: - Weather Widget

struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("天气")
        .description("显示当前天气信息")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Weather Widget View

struct WeatherWidgetView: View {
    let entry: WeatherEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small View

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 28))
                .foregroundColor(.yellow)

            Text("\(Int(entry.temperature))°C")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(entry.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    // MARK: - Medium View

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：图标 + 温度
            VStack(spacing: 4) {
                Image(systemName: entry.iconSystemName)
                    .font(.system(size: 32))
                    .foregroundColor(.yellow)

                Text("\(Int(entry.temperature))°C")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Divider()

            // 右侧：详细信息
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.description)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    Label("\(entry.humidity)%", systemImage: "humidity.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Label(String(format: "%.0f km/h", entry.windSpeed), systemImage: "wind")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    WeatherWidget()
} timeline: {
    WeatherEntry.placeholder
}
