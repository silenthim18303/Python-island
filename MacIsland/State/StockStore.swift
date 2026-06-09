//
//  StockStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation
import SwiftUI
import Combine

/// 股票数据存储
@MainActor
final class StockStore: ObservableObject {
    static let shared = StockStore()

    // MARK: - Published Properties

    /// 自选股列表
    @Published var watchlist: [WatchlistItem] = []

    /// 实时行情数据 (symbol -> quote)
    @Published var quotes: [String: StockQuote] = [:]

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var error: String?

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let watchlist = "stock_watchlist"
    }

    // MARK: - Initialization

    private init() {
        loadWatchlist()
    }

    // MARK: - 自选股管理

    /// 添加自选股
    func addToWatchlist(_ stock: StockItem) {
        // 检查是否已存在
        guard !watchlist.contains(where: { $0.id == stock.id }) else { return }

        let item = WatchlistItem.create(from: stock, sortOrder: watchlist.count)
        watchlist.append(item)
        saveWatchlist()
    }

    /// 移除自选股
    func removeFromWatchlist(symbol: String) {
        watchlist.removeAll { $0.id == symbol }
        quotes.removeValue(forKey: symbol)
        saveWatchlist()
    }

    /// 移动自选股排序
    func moveWatchlistItem(from source: IndexSet, to destination: Int) {
        watchlist.move(fromOffsets: source, toOffset: destination)
        // 更新排序
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

    /// 更新行情数据
    func updateQuote(_ quote: StockQuote) {
        quotes[quote.symbol] = quote
    }

    /// 批量更新行情
    func updateQuotes(_ newQuotes: [StockQuote]) {
        for quote in newQuotes {
            quotes[quote.symbol] = quote
        }
    }

    /// 获取指定股票行情
    func getQuote(symbol: String) -> StockQuote? {
        return quotes[symbol]
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
}
