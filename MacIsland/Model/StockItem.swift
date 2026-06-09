//
//  StockItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 股票市场

/// 股票市场类型
enum StockMarket: String, Codable, CaseIterable {
    case aShare = "a_share"     // A股
    case usStock = "us_stock"   // 美股
    case hkStock = "hk_stock"   // 港股

    var displayName: String {
        switch self {
        case .aShare: return "A股"
        case .usStock: return "美股"
        case .hkStock: return "港股"
        }
    }

    var currency: String {
        switch self {
        case .aShare: return "CNY"
        case .usStock: return "USD"
        case .hkStock: return "HKD"
        }
    }

    /// 股票代码前缀
    var codePrefix: String {
        switch self {
        case .aShare: return ""
        case .usStock: return ""
        case .hkStock: return ""
        }
    }
}

// MARK: - 股票数据模型

/// 股票基础数据模型
struct StockItem: Codable, Identifiable, Hashable {
    let id: String              // 股票代码 (如 "600519", "AAPL", "0700")
    let name: String            // 股票名称
    let market: StockMarket     // 所属市场
    let industry: String?       // 行业分类

    // TODO: - 实现 Codable 和 Hashable 协议

    /// 格式化显示名称
    var displayName: String {
        return "\(name) (\(id))"
    }

    /// 市场标识
    var marketTag: String {
        return market.displayName
    }
}

// MARK: - 实时行情

/// 股票实时行情数据
struct StockQuote: Codable, Identifiable {
    var id: String { symbol }

    let symbol: String          // 股票代码
    let name: String            // 股票名称
    let market: StockMarket     // 市场

    // 价格数据
    var currentPrice: Double    // 最新价
    var previousClose: Double   // 昨收
    var openPrice: Double       // 开盘价
    var highPrice: Double       // 最高价
    var lowPrice: Double        // 最低价

    // 变动数据
    var changeAmount: Double    // 涨跌额
    var changePercent: Double   // 涨跌幅 (%)

    // 成交数据
    var volume: Int64           // 成交量
    var turnover: Double        // 成交额

    // 时间
    var updatedAt: Date         // 更新时间

    // MARK: - 计算属性

    /// 涨跌状态
    var isUp: Bool { changeAmount > 0 }
    var isDown: Bool { changeAmount < 0 }
    var isFlat: Bool { changeAmount == 0 }

    /// 格式化涨跌幅
    var changePercentString: String {
        let prefix = isUp ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", changePercent))%"
    }

    /// 格式化涨跌额
    var changeAmountString: String {
        let prefix = isUp ? "+" : ""
        return "\(prefix)\(String(format: "%.2f", changeAmount))"
    }

    /// 格式化当前价格
    var priceString: String {
        return String(format: "%.2f", currentPrice)
    }

    /// 涨跌颜色标识
    var trendColor: StockTrendColor {
        if isUp { return .up }
        if isDown { return .down }
        return .flat
    }
}

// MARK: - 涨跌颜色

enum StockTrendColor {
    case up      // 上涨 (红/绿取决于市场)
    case down    // 下跌
    case flat    // 平盘

    /// 中国市场：红涨绿跌
    /// 美国市场：绿涨红跌
    func color(for market: StockMarket) -> StockColor {
        switch (self, market) {
        case (.up, .aShare), (.up, .hkStock): return .red
        case (.up, .usStock): return .green
        case (.down, .aShare), (.down, .hkStock): return .green
        case (.down, .usStock): return .red
        case (.flat, _): return .secondary
        }
    }
}

enum StockColor {
    case red, green, secondary
}

// MARK: - 分时数据

/// 分时数据点
struct StockTimePoint: Codable, Identifiable {
    let id = UUID()
    let time: Date
    let price: Double
    let volume: Int64

    enum CodingKeys: String, CodingKey {
        case time, price, volume
    }
}

// MARK: - K线数据

/// K线数据点
struct StockKLinePoint: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64

    enum CodingKeys: String, CodingKey {
        case date, open, high, low, close, volume
    }

    /// 是否为阳线（收盘 > 开盘）
    var isBullish: Bool { close > open }

    /// 实体高度
    var bodyHeight: Double { abs(close - open) }

    /// 上影线长度
    var upperShadow: Double { high - max(open, close) }

    /// 下影线长度
    var lowerShadow: Double { min(open, close) - low }
}
