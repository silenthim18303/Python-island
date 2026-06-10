//
//  StockServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation
import Combine

/// 股票服务实现 — 提供数据获取接口，行情存储统一由 StockStore 管理
@MainActor
final class StockServiceImpl: ObservableObject, StockServiceProtocol {
    /// 行情数据（代理读取自 StockStore）
    var quotes: [String: StockQuote] { StockStore.shared.quotes }

    @Published var isLoading = false
    @Published var error: String?
    @Published var isAutoRefreshEnabled = false

    // MARK: - Private

    private let dataProvider = StockDataProvider()

    // MARK: - 股票服务实现

    func fetchQuote(for symbol: String, market: StockMarket) async throws -> StockQuote {
        isLoading = true
        defer { isLoading = false }

        do {
            let quote = try await dataProvider.fetchQuote(symbol: symbol, market: market)
            StockStore.shared.updateQuote(quote)
            return quote
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func fetchQuotes(symbols: [(String, StockMarket)]) async throws -> [StockQuote] {
        isLoading = true
        defer { isLoading = false }

        do {
            let newQuotes = try await dataProvider.fetchBatchQuotes(symbols: symbols)
            StockStore.shared.updateQuotes(newQuotes)
            return newQuotes
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func searchStocks(keyword: String, market: StockMarket?) async throws -> [StockItem] {
        return try await dataProvider.searchStocks(keyword: keyword, market: market)
    }

    func fetchKLineData(symbol: String, market: StockMarket, period: KLinePeriod) async throws -> [StockKLinePoint] {
        return try await dataProvider.fetchKLineData(symbol: symbol, market: market, period: period)
    }

    func fetchTimeLineData(symbol: String, market: StockMarket) async throws -> [StockTimePoint] {
        return try await dataProvider.fetchTimeLineData(symbol: symbol, market: market)
    }

    // MARK: - 自动刷新（委托给 StockStore）

    func startAutoRefresh(interval: TimeInterval = 60) {
        StockStore.shared.startAutoRefresh(interval: interval)
        isAutoRefreshEnabled = true
    }

    func stopAutoRefresh() {
        StockStore.shared.stopAutoRefresh()
        isAutoRefreshEnabled = false
    }

    func refreshWatchlist(_ watchlist: [WatchlistItem]) async {
        await StockStore.shared.refreshAllQuotes()
    }
}
