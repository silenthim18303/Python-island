//
//  StockServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation
import Combine

/// 股票服务实现
@MainActor
final class StockServiceImpl: ObservableObject, StockServiceProtocol {
    @Published var quotes: [String: StockQuote] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAutoRefreshEnabled = false

    // MARK: - Private

    private let dataProvider = StockDataProvider()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 股票服务实现

    func fetchQuote(for symbol: String, market: StockMarket) async throws -> StockQuote {
        isLoading = true
        defer { isLoading = false }

        do {
            let quote = try await dataProvider.fetchQuote(symbol: symbol, market: market)
            quotes[symbol] = quote
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
            for quote in newQuotes {
                quotes[quote.symbol] = quote
            }
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

    // MARK: - 自动刷新

    func startAutoRefresh(interval: TimeInterval = 60) {
        stopAutoRefresh()
        isAutoRefreshEnabled = true

        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let watchlist = StockStore.shared.watchlist
                await self.refreshWatchlist(watchlist)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isAutoRefreshEnabled = false
    }

    func refreshWatchlist(_ watchlist: [WatchlistItem]) async {
        guard !watchlist.isEmpty else { return }

        let symbols = watchlist.map { ($0.id, $0.market) }
        do {
            _ = try await fetchQuotes(symbols: symbols)
            // 更新小组件数据
            updateWidgetData()
        } catch {
            print("[StockService] Refresh failed: \(error)")
        }
    }

    // MARK: - 小组件数据更新

    private func updateWidgetData() {
        let stockItems: [[String: Any]] = StockStore.shared.watchlist.prefix(5).compactMap { item in
            guard let quote = quotes[item.id] else { return nil }
            return [
                "symbol": quote.symbol,
                "name": quote.name,
                "price": quote.currentPrice,
                "change_percent": quote.changePercent,
                "change_amount": quote.changeAmount,
                "is_up": quote.isUp,
            ]
        }

        WidgetDataManager.shared.updateStocks(items: stockItems)
    }
}
