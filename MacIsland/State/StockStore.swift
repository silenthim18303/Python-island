//
//  StockStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation
import SwiftUI
import Combine

/// 股票数据存储 — 行情 + 自选股的唯一数据源
@MainActor
final class StockStore: ObservableObject {
    static let shared = StockStore()

    // MARK: - Published Properties

    /// 自选股列表
    @Published var watchlist: [WatchlistItem] = []

    /// 实时行情数据 (symbol -> quote) — 唯一数据源
    @Published var quotes: [String: StockQuote] = [:]

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var error: String?

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var refreshCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let watchlist = "stock_watchlist"
        static let quotes = "stock_quotes"
    }

    // MARK: - Initialization

    private init() {
        loadWatchlist()
        loadQuotes()
        setupWatchlistObserver()
    }

    // MARK: - 自选股管理

    /// 添加自选股 — 自动触发该股票的行情获取
    func addToWatchlist(_ stock: StockItem) {
        guard !watchlist.contains(where: { $0.id == stock.id }) else { return }

        let item = WatchlistItem.create(from: stock, sortOrder: watchlist.count)
        watchlist.append(item)
        saveWatchlist()
        // 立即获取新添加股票的行情
        Task { await fetchQuoteForNewStock(item) }
    }

    /// 移除自选股
    func removeFromWatchlist(symbol: String) {
        watchlist.removeAll { $0.id == symbol }
        quotes.removeValue(forKey: symbol)
        saveWatchlist()
        saveQuotes()
        updateWidgetData()
    }

    /// 移动自选股排序
    func moveWatchlistItem(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
        for (index, item) in watchlist.enumerated() {
            watchlist[index] = WatchlistItem(
                id: item.id,
                name: item.name,
                market: item.market,
                sortOrder: index,
                addedAt: item.addedAt
            )
        }
        saveWatchlist()
    }

    /// 检查是否在自选中
    func isInWatchlist(symbol: String) -> Bool {
        return watchlist.contains { $0.id == symbol }
    }

    // MARK: - 行情数据

    /// 更新单条行情
    func updateQuote(_ quote: StockQuote) {
        quotes[quote.symbol] = quote
    }

    /// 批量更新行情
    func updateQuotes(_ newQuotes: [StockQuote]) {
        for quote in newQuotes {
            quotes[quote.symbol] = quote
        }
        saveQuotes()
        updateWidgetData()
    }

    /// 获取指定股票行情
    func getQuote(symbol: String) -> StockQuote? {
        return quotes[symbol]
    }

    /// 刷新所有自选股行情
    func refreshAllQuotes() async {
        guard !watchlist.isEmpty else {
            print("[StockStore] 自选股为空，跳过刷新")
            return
        }

        isLoading = true
        error = nil

        let dataProvider = StockDataProvider()
        let symbols = watchlist.map { ($0.id, $0.market) }

        do {
            let newQuotes = try await dataProvider.fetchBatchQuotes(symbols: symbols)
            for quote in newQuotes {
                quotes[quote.symbol] = quote
            }
            saveQuotes()
            updateWidgetData()
        } catch {
            self.error = error.localizedDescription
            print("[StockStore] Refresh failed: \(error)")
        }

        isLoading = false
    }

    // MARK: - 自动刷新

    /// 启动自动刷新
    func startAutoRefresh(interval: TimeInterval) {
        stopAutoRefresh()

        refreshCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshAllQuotes()
                }
            }
    }

    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshCancellable = nil
    }

    // MARK: - 监听自选股变化

    private func setupWatchlistObserver() {
        // 监听自选股列表变化，自动同步小组件数据
        $watchlist
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWidgetData()
            }
            .store(in: &cancellables)
    }

    // MARK: - 新股票行情获取

    /// 为新添加的自选股立即获取行情
    private func fetchQuoteForNewStock(_ item: WatchlistItem) async {
        let dataProvider = StockDataProvider()
        do {
            let quote = try await dataProvider.fetchQuote(symbol: item.id, market: item.market)
            quotes[item.id] = quote
            saveQuotes()
            updateWidgetData()
        } catch {
        }
    }

    // MARK: - 小组件数据同步

    private func updateWidgetData() {
        let stockItems: [[String: Any]] = watchlist.prefix(5).compactMap { item in
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

    // MARK: - 持久化

    private func loadWatchlist() {
        guard let data = defaults.data(forKey: Keys.watchlist),
              let items = try? decoder.decode([WatchlistItem].self, from: data) else {
            return
        }
        watchlist = items
    }

    private func saveWatchlist() {
        guard let data = try? encoder.encode(watchlist) else { return }
        defaults.set(data, forKey: Keys.watchlist)
    }

    /// 持久化行情数据（启动时可快速展示上次数据）
    private func saveQuotes() {
        guard let data = try? encoder.encode(quotes) else { return }
        defaults.set(data, forKey: Keys.quotes)
    }

    private func loadQuotes() {
        guard let data = defaults.data(forKey: Keys.quotes),
              let decoded = try? decoder.decode([String: StockQuote].self, from: data) else {
            return
        }
        quotes = decoded
    }
}
