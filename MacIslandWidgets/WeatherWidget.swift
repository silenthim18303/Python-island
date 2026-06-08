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
    func placeholder(in context: Context) -> WeatherEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) { completion(.placeholder) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let entry = WeatherEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Weather Entry

struct WeatherEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let temperature: Double
    let temperatureMax: Double
    let temperatureMin: Double
    let description: String
    let iconSystemName: String
    let humidity: Int
    let windSpeed: Double
    let cityName: String
    let districtName: String
    let updatedAt: Date?

    static var placeholder: WeatherEntry {
        WeatherEntry(date: Date(), hasData: true, temperature: 22,
                     temperatureMax: 26, temperatureMin: 18,
                     description: "晴", iconSystemName: "sun.max.fill",
                     humidity: 45, windSpeed: 12, cityName: "北京",
                     districtName: "朝阳", updatedAt: Date())
    }

    static func fromUserDefaults() -> WeatherEntry {
        let ts = WidgetConstants.double("widget_weather_updated_at")
        return WeatherEntry(
            date: Date(),
            hasData: WidgetConstants.bool("widget_weather_hasData"),
            temperature: WidgetConstants.double("widget_weather_temperature"),
            temperatureMax: WidgetConstants.double("widget_weather_temperature_max"),
            temperatureMin: WidgetConstants.double("widget_weather_temperature_min"),
            description: WidgetConstants.string("widget_weather_description") ?? "--",
            iconSystemName: WidgetConstants.string("widget_weather_icon") ?? "cloud.fill",
            humidity: WidgetConstants.int("widget_weather_humidity"),
            windSpeed: WidgetConstants.double("widget_weather_windSpeed"),
            cityName: WidgetConstants.string("widget_weather_city") ?? "",
            districtName: WidgetConstants.string("widget_weather_district") ?? "",
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        )
    }

    var temperatureString: String { "\(Int(temperature))°" }
    var rangeString: String { "\(Int(temperatureMin))°/\(Int(temperatureMax))°" }
    var humidityString: String { "\(humidity)%" }
    var windString: String { String(format: "%.0f km/h", windSpeed) }
    var updateString: String { WidgetFormat.relativeTime(updatedAt) }

    var locationTitle: String {
        if cityName.isEmpty && districtName.isEmpty { return WidgetL10n.weatherCurrentLocation }
        if districtName.isEmpty { return cityName }
        if cityName.isEmpty { return districtName }
        let city = cityName.hasSuffix("市") ? String(cityName.dropLast()) : cityName
        return "\(city) \(districtName)"
    }
}

// MARK: - Weather Widget

struct WeatherWidget: Widget {
    let kind = "WeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName(WidgetL10n.weatherDisplayName)
        .description(WidgetL10n.weatherDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        case .systemLarge: largeView
        default: smallView
        }
    }

    // MARK: - Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entry.hasData {
                WidgetHeader(icon: "location.fill", title: entry.locationTitle, trailing: entry.updateString, color: .orange)

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.temperatureString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(entry.description)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: entry.iconSystemName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.yellow, .orange)
                }

                WidgetInfoRow(icon: "thermometer.medium", title: WidgetL10n.weatherHighLow, value: entry.rangeString, color: .orange)
                WidgetInfoRow(icon: "humidity.fill", title: WidgetL10n.weatherHumidity, value: entry.humidityString, color: .cyan)
            } else {
                Spacer()
                WidgetEmptyState(icon: "cloud.sun", message: WidgetL10n.weatherSyncHint)
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.hasData {
                WidgetHeader(icon: "cloud.sun.fill", title: entry.locationTitle, trailing: entry.updateString, color: .orange)

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: entry.iconSystemName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.yellow, .orange)
                        Text(entry.temperatureString)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(entry.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 86, alignment: .leading)

                    Divider()

                    VStack(spacing: 7) {
                        WidgetInfoRow(icon: "thermometer.medium", title: WidgetL10n.weatherHighLow, value: entry.rangeString, color: .orange)
                        WidgetInfoRow(icon: "humidity.fill", title: WidgetL10n.weatherHumidity, value: entry.humidityString, color: .cyan)
                        WidgetInfoRow(icon: "wind", title: WidgetL10n.weatherWindSpeed, value: entry.windString, color: .blue)
                    }
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "cloud.sun", message: WidgetL10n.weatherOpenHint)
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if entry.hasData {
                WidgetHeader(icon: "cloud.sun.fill", title: entry.locationTitle, trailing: entry.updateString, color: .orange)

                // 温度 + 天气图标
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.temperatureString)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(entry.description)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: entry.iconSystemName)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.yellow, .orange)
                }

                // 温度范围条
                TemperatureRangeBar(min: entry.temperatureMin, max: entry.temperatureMax, current: entry.temperature)

                Divider()

                // 详细信息网格
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 10) {
                    WeatherDetailCard(icon: "thermometer.medium", title: "最高温", value: "\(Int(entry.temperatureMax))°", color: .red)
                    WeatherDetailCard(icon: "thermometer.low", title: "最低温", value: "\(Int(entry.temperatureMin))°", color: .blue)
                    WeatherDetailCard(icon: "humidity.fill", title: WidgetL10n.weatherHumidity, value: entry.humidityString, color: .cyan)
                    WeatherDetailCard(icon: "wind", title: WidgetL10n.weatherWindSpeed, value: entry.windString, color: .green)
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "cloud.sun", message: WidgetL10n.weatherOpenHint)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Temperature Range Bar

private struct TemperatureRangeBar: View {
    let min: Double
    let max: Double
    let current: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(Int(min))°")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                Spacer()
                Text("当前 \(Int(current))°")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int(max))°")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(colors: [.blue, .green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(height: 6)

                    // 当前温度指示器
                    let range = max - min
                    let position = range > 0 ? (current - min) / range : 0.5
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: geo.size.width * position - 5)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Weather Detail Card

private struct WeatherDetailCard: View {
    let icon: String
    let title: String
    let value: String
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}
