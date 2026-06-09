//
//  StockDataProvider.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 数据源类型

/// 股票数据源
enum StockDataSource: String, CaseIterable {
    case sina = "sina"         // 新浪财经
    case tencent = "tencent"   // 腾讯财经
    case eastmoney = "eastmoney" // 东方财富
    case yahoo = "yahoo"       // Yahoo Finance

    var displayName: String {
        switch self {
        case .sina: return "新浪财经"
        case .tencent: return "腾讯财经"
        case .eastmoney: return "东方财富"
        case .yahoo: return "Yahoo Finance"
        }
    }

    /// 支持的市场
    var supportedMarkets: [StockMarket] {
        switch self {
        case .sina: return [.aShare, .hkStock]
        case .tencent: return [.aShare, .hkStock]
        case .eastmoney: return [.aShare]
        case .yahoo: return [.usStock, .hkStock]
        }
    }
}

// MARK: - 数据提供者

/// 股票数据提供者 - 抽象层
final class StockDataProvider {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - 获取行情

    /// 获取单只股票行情
    func fetchQuote(symbol: String, market: StockMarket) async throws -> StockQuote {
        // TODO: - 根据市场选择合适的数据源
        // A股/港股: 新浪财经 或 腾讯财经
        // 美股: Yahoo Finance

        switch market {
        case .aShare:
            return try await fetchSinaQuote(symbol: symbol, market: market)
        case .usStock:
            return try await fetchYahooQuote(symbol: symbol)
        case .hkStock:
            return try await fetchSinaQuote(symbol: symbol, market: market)
        }
    }

    /// 批量获取行情
    func fetchBatchQuotes(symbols: [(String, StockMarket)]) async throws -> [StockQuote] {
        // TODO: - 实现批量获取，减少请求次数
        // 新浪财经支持批量查询: hq.sinajs.cn/list=sh600519,sz000858

        var results: [StockQuote] = []
        for (symbol, market) in symbols {
            let quote = try await fetchQuote(symbol: symbol, market: market)
            results.append(quote)
        }
        return results
    }

    // MARK: - 搜索股票

    /// 搜索股票
    func searchStocks(keyword: String, market: StockMarket?) async throws -> [StockItem] {
        // TODO: - 实现股票搜索
        // 可以使用东方财富搜索 API 或本地缓存

        // 临时返回空数组
        return []
    }

    // MARK: - K线数据

    /// 获取K线数据
    func fetchKLineData(symbol: String, market: StockMarket, period: KLinePeriod) async throws -> [StockKLinePoint] {
        // TODO: - 实现K线数据获取
        // A股: 东方财富 K线 API
        // 美股: Yahoo Finance K线 API

        return []
    }

    /// 获取分时数据
    func fetchTimeLineData(symbol: String, market: StockMarket) async throws -> [StockTimePoint] {
        // TODO: - 实现分时数据获取

        return []
    }

    // MARK: - 新浪财经 API

    /// 从新浪财经获取行情
    private func fetchSinaQuote(symbol: String, market: StockMarket) async throws -> StockQuote {
        // TODO: - 实现新浪财经 API 调用
        // API: https://hq.sinajs.cn/list=sh600519
        // 返回格式: var hq_str_sh600519="贵州茅台,1849.00,1847.00,...";

        throw StockAPIError.symbolNotFound
    }

    // MARK: - Yahoo Finance API

    /// 从 Yahoo Finance 获取行情
    private func fetchYahooQuote(symbol: String) async throws -> StockQuote {
        // TODO: - 实现 Yahoo Finance API 调用
        // API: https://query1.finance.yahoo.com/v8/finance/chart/AAPL

        throw StockAPIError.symbolNotFound
    }

    // MARK: - 东方财富 API

    /// 从东方财富获取行情
    private func fetchEastmoneyQuote(symbol: String) async throws -> StockQuote {
        // TODO: - 实现东方财富 API 调用
        // API: https://push2.eastmoney.com/api/qt/stock/get?secid=1.600519

        throw StockAPIError.symbolNotFound
    }
}
