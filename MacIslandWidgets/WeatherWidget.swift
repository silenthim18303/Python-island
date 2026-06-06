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
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let entry = WeatherEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        WeatherEntry(date: Date(), temperature: 22, description: "Sunny",
                     iconSystemName: "sun.max.fill", humidity: 45, windSpeed: 12)
    }

    static func fromUserDefaults() -> WeatherEntry {
        let d = WidgetConstants.sharedDefaults
        return WeatherEntry(
            date: Date(),
            temperature: d.double(forKey: "widget_weather_temperature"),
            description: d.string(forKey: "widget_weather_description") ?? "--",
            iconSystemName: d.string(forKey: "widget_weather_icon") ?? "cloud.fill",
            humidity: d.integer(forKey: "widget_weather_humidity"),
            windSpeed: d.double(forKey: "widget_weather_windSpeed")
        )
    }

    var temperatureString: String { "\(Int(temperature))°" }
    var humidityString: String { "\(humidity)%" }
    var windString: String { String(format: "%.0f km/h", windSpeed) }
}

// MARK: - Weather Widget

struct WeatherWidget: Widget {
    let kind = "WeatherWidget"

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
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 28))
                .foregroundStyle(.yellow, .orange)

            Text(entry.temperatureString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(entry.description)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // 左侧：图标 + 温度
            VStack(spacing: 6) {
                Image(systemName: entry.iconSystemName)
                    .font(.system(size: 32))
                    .foregroundStyle(.yellow, .orange)

                Text(entry.temperatureString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(width: 80)

            Divider()

            // 右侧：详细信息
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.description)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    Label(entry.humidityString, systemImage: "humidity.fill")
                    Label(entry.windString, systemImage: "wind")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
