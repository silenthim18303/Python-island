//
//  StockServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 股票服务协议

/// 股票服务协议
protocol StockServiceProtocol: AnyObject {
    /// 实时行情数据
    var quotes: [String: StockQuote] { get }
    /// 是否正在加载
    var isLoading: Bool { get }
    /// 错误信息
    var error: String? { get }
    /// 自动刷新是否启用
    var isAutoRefreshEnabled: Bool { get }

    /// 获取单只股票行情
    func fetchQuote(for symbol: String, market: StockMarket) async throws -> StockQuote

    /// 批量获取行情
    func fetchQuotes(symbols: [(String, StockMarket)]) async throws -> [StockQuote]

    /// 搜索股票
    func searchStocks(keyword: String, market: StockMarket?) async throws -> [StockItem]

    /// 获取K线数据
    func fetchKLineData(symbol: String, market: StockMarket, period: KLinePeriod) async throws -> [StockKLinePoint]

    /// 获取分时数据
    func fetchTimeLineData(symbol: String, market: StockMarket) async throws -> [StockTimePoint]

    /// 开始自动刷新
    func startAutoRefresh(interval: TimeInterval)

    /// 停止自动刷新
    func stopAutoRefresh()

    /// 刷新所有自选股
    func refreshWatchlist(_ watchlist: [WatchlistItem]) async
}

// MARK: - K线周期

/// K线数据周期
enum KLinePeriod: String, CaseIterable {
    case day = "1d"         // 日K
    case week = "1w"        // 周K
    case month = "1m"       // 月K
    case minute1 = "1min"   // 1分钟
    case minute5 = "5min"   // 5分钟
    case minute15 = "15min" // 15分钟
    case minute30 = "30min" // 30分钟
    case hour1 = "1h"       // 1小时

    var displayName: String {
        switch self {
        case .day: return "日K"
        case .week: return "周K"
        case .month: return "月K"
        case .minute1: return "1分"
        case .minute5: return "5分"
        case .minute15: return "15分"
        case .minute30: return "30分"
        case .hour1: return "1小时"
        }
    }
}

// MARK: - API 错误

/// 股票 API 错误
enum StockAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case rateLimited
    case symbolNotFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的请求地址"
        case .networkError(let error): return "网络错误: \(error.localizedDescription)"
        case .invalidResponse: return "无效的响应数据"
        case .decodingError: return "数据解析失败"
        case .rateLimited: return "请求过于频繁，请稍后再试"
        case .symbolNotFound: return "未找到该股票"
        case .serverError(let code): return "服务器错误 (\(code))"
        }
    }
}
