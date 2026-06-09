//
//  StockWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/9.
//

import WidgetKit
import SwiftUI

// MARK: - Stock Timeline Provider

struct StockTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StockEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (StockEntry) -> Void) { completion(.placeholder) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StockEntry>) -> Void) {
        let entry = StockEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Stock Entry

struct StockEntry: TimelineEntry {
    let date: Date
    let stocks: [StockData]
    let updatedAt: Date?

    struct StockData: Identifiable {
        let id: String
        let name: String
        let price: Double
        let changePercent: Double
        let changeAmount: Double
        let isUp: Bool

        var priceString: String { String(format: "%.2f", price) }
        var changePercentString: String {
            let prefix = isUp ? "+" : ""
            return "\(prefix)\(String(format: "%.2f", changePercent))%"
        }
    }

    static var placeholder: StockEntry {
        StockEntry(
            date: Date(),
            stocks: [
                StockData(id: "AAPL", name: "Apple", price: 189.84, changePercent: 1.25, changeAmount: 2.35, isUp: true),
                StockData(id: "GOOGL", name: "Google", price: 141.80, changePercent: -0.52, changeAmount: -0.74, isUp: false),
                StockData(id: "MSFT", name: "Microsoft", price: 417.88, changePercent: 0.89, changeAmount: 3.70, isUp: true),
            ],
            updatedAt: Date()
        )
    }

    static func fromUserDefaults() -> StockEntry {
        let d = WidgetConstants.sharedDefaults
        let ts = d.double(forKey: "widget_stock_updated_at")
        var stocks: [StockData] = []

        if let data = d.data(forKey: "widget_stock_items"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for dict in json {
                if let symbol = dict["symbol"] as? String,
                   let name = dict["name"] as? String,
                   let price = dict["price"] as? Double {
                    let changePercent = dict["change_percent"] as? Double ?? 0
                    let changeAmount = dict["change_amount"] as? Double ?? 0
                    let isUp = dict["is_up"] as? Bool ?? false
                    stocks.append(StockData(
                        id: symbol, name: name, price: price,
                        changePercent: changePercent, changeAmount: changeAmount, isUp: isUp
                    ))
                }
            }
        }

        return StockEntry(
            date: Date(),
            stocks: stocks,
            updatedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        )
    }
}

// MARK: - Stock Widget

struct StockWidget: Widget {
    let kind = "StockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StockTimelineProvider()) { entry in
            StockWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName("股票")
        .description("显示自选股行情")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Stock Widget View

struct StockWidgetView: View {
    let entry: StockEntry
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
            if let first = entry.stocks.first {
                WidgetHeader(icon: "chart.line.uptrend.xyaxis", title: first.name, trailing: entry.updateString, color: .green)

                Text(first.priceString)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                HStack {
                    Text(first.changePercentString)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(first.isUp ? .red : .green)
                    Spacer()
                    Text("\(entry.stocks.count) 只")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "chart.line.uptrend.xyaxis", message: "暂无自选股")
                Spacer()
            }
        }
        .padding()
    }

    // MARK: - Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(icon: "chart.line.uptrend.xyaxis", title: "自选股", trailing: entry.updateString, color: .green)

            if entry.stocks.isEmpty {
                Spacer()
                WidgetEmptyState(icon: "chart.line.uptrend.xyaxis", message: "请在主应用中添加自选股")
                Spacer()
            } else {
                ForEach(entry.stocks.prefix(3)) { stock in
                    stockRow(stock)
                }
            }
        }
        .padding()
    }

    // MARK: - Large

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(icon: "chart.line.uptrend.xyaxis", title: "自选股", trailing: entry.updateString, color: .green)

            if entry.stocks.isEmpty {
                Spacer()
                WidgetEmptyState(icon: "chart.line.uptrend.xyaxis", message: "请在主应用中添加自选股")
                Spacer()
            } else {
                ForEach(entry.stocks.prefix(6)) { stock in
                    stockRow(stock)
                }
            }
        }
        .padding()
    }

    // MARK: - Stock Row

    private func stockRow(_ stock: StockEntry.StockData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(stock.id)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(stock.priceString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text(stock.changePercentString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(stock.isUp ? .red : .green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper

extension StockEntry {
    var updateString: String {
        WidgetFormat.relativeTime(updatedAt)
    }
}
