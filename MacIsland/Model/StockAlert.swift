//
//  StockAlert.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 提醒条件类型

/// 股票提醒条件
enum AlertCondition: String, Codable, CaseIterable {
    case priceAbove = "price_above"     // 价格高于
    case priceBelow = "price_below"     // 价格低于
    case percentUp = "percent_up"       // 涨幅超过
    case percentDown = "percent_down"   // 跌幅超过

    var displayName: String {
        switch self {
        case .priceAbove: return "价格高于"
        case .priceBelow: return "价格低于"
        case .percentUp: return "涨幅超过"
        case .percentDown: return "跌幅超过"
        }
    }

    var systemImage: String {
        switch self {
        case .priceAbove: return "arrow.up.circle"
        case .priceBelow: return "arrow.down.circle"
        case .percentUp: return "chart.line.uptrend.xyaxis"
        case .percentDown: return "chart.line.downtrend.xyaxis"
        }
    }
}

// MARK: - 股票提醒模型

/// 股票涨跌提醒
struct StockAlert: Codable, Identifiable {
    let id: UUID
    let symbol: String          // 股票代码
    let stockName: String       // 股票名称
    let condition: AlertCondition  // 触发条件
    let targetValue: Double     // 目标值（价格或百分比）
    var isEnabled: Bool         // 是否启用
    var isTriggered: Bool       // 是否已触发
    var triggeredAt: Date?      // 触发时间
    let createdAt: Date         // 创建时间

    /// 格式化目标值
    var targetValueString: String {
        switch condition {
        case .priceAbove, .priceBelow:
            return String(format: "%.2f", targetValue)
        case .percentUp, .percentDown:
            return String(format: "%.1f%%", targetValue)
        }
    }

    /// 检查是否满足触发条件
    func shouldTrigger(quote: StockQuote) -> Bool {
        guard isEnabled && !isTriggered else { return false }

        switch condition {
        case .priceAbove:
            return quote.currentPrice >= targetValue
        case .priceBelow:
            return quote.currentPrice <= targetValue
        case .percentUp:
            return quote.changePercent >= targetValue
        case .percentDown:
            return quote.changePercent <= -targetValue
        }
    }
}

// MARK: - 自选股项目

/// 自选股列表项
struct WatchlistItem: Codable, Identifiable, Hashable {
    let id: String              // 股票代码
    let name: String            // 股票名称
    let market: StockMarket     // 市场
    var sortOrder: Int          // 排序顺序
    let addedAt: Date           // 添加时间

    /// 创建自选股
    static func create(from stock: StockItem, sortOrder: Int = 0) -> WatchlistItem {
        return WatchlistItem(
            id: stock.id,
            name: stock.name,
            market: stock.market,
            sortOrder: sortOrder,
            addedAt: Date()
        )
    }
}
