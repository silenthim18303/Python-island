//
//  StockListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

/// 自选股统一视图 — 内联搜索 + 市场筛选 + 自选股管理
/// 展开态与最大展开态共用此组件，保证数据和 UI 同步
struct StockListView: View {
    @EnvironmentObject var stockStore: StockStore
    @EnvironmentObject var stockService: StockServiceImpl

    @State private var searchText = ""
    @State private var searchResults: [StockItem] = []
    @State private var isSearching = false
    @State private var selectedMarket: StockMarket? = nil
    @State private var searchTask: Task<Void, Never>?

    /// 按市场筛选后的自选股
    private var filteredWatchlist: [WatchlistItem] {
        if let market = selectedMarket {
            return stockStore.watchlist.filter { $0.market == market }
        }
        return stockStore.watchlist
    }

    var body: some View {
        VStack(spacing: 10) {
            searchBar
            marketFilter
            contentView
        }
        .onAppear {
            if !stockStore.watchlist.isEmpty && stockStore.quotes.isEmpty {
                Task { await stockStore.refreshAllQuotes() }
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if !searchText.isEmpty {
            searchResultsSection
        } else {
            watchlistSection
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)

            TextField(L10n.stockSearch, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .onSubmit { performSearch() }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    searchTask?.cancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            // 手动刷新
            Button {
                Task { await stockStore.refreshAllQuotes() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(stockStore.isLoading ? 360 : 0))
                    .animation(stockStore.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: stockStore.isLoading)
            }
            .buttonStyle(.plain)
            .disabled(stockStore.isLoading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fillSubtle))
    }

    // MARK: - Market Filter

    private var marketFilter: some View {
        HStack(spacing: 6) {
            marketChip(nil, label: L10n.stockAllMarkets, count: stockStore.watchlist.count)
            ForEach(StockMarket.allCases, id: \.self) { market in
                let count = stockStore.watchlist.filter { $0.market == market }.count
                marketChip(market, label: market.displayName, count: count)
            }
            Spacer()
        }
    }

    private func marketChip(_ market: StockMarket?, label: String, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedMarket = market
            }
            if !searchText.isEmpty { performSearch() }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.7)
                }
            }
            .font(.system(size: 11, weight: selectedMarket == market ? .semibold : .medium))
            .foregroundColor(selectedMarket == market ? .white : .textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(selectedMarket == market ? Color.accentColor.opacity(0.3) : Color.fillSubtle)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.stockSearchResults)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(searchResults.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }

            if searchResults.isEmpty && !isSearching {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.textTertiary)
                        Text(L10n.stockNoResults)
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(searchResults) { stock in
                    searchResultRow(stock)
                }
            }
        }
    }

    private func searchResultRow(_ stock: StockItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                HStack(spacing: 4) {
                    Text(stock.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textTertiary)
                    Text(stock.market.displayName)
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.fillSubtle))
                }
            }

            Spacer()

            Button {
                stockStore.addToWatchlist(stock)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: stockStore.isInWatchlist(symbol: stock.id) ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(stockStore.isInWatchlist(symbol: stock.id) ? L10n.stockAdded : L10n.stockAdd)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(stockStore.isInWatchlist(symbol: stock.id) ? .green : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(stockStore.isInWatchlist(symbol: stock.id)
                            ? Color.green.opacity(0.15)
                            : Color.accentColor.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(stockStore.isInWatchlist(symbol: stock.id))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fillSubtle))
    }

    // MARK: - Watchlist Section

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                Text(L10n.stockWatchlist)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(filteredWatchlist.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
            }

            if filteredWatchlist.isEmpty {
                emptyWatchlist
            } else {
                ForEach(filteredWatchlist) { item in
                    watchlistRow(item)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        stockStore.removeFromWatchlist(symbol: filteredWatchlist[index].id)
                    }
                }
            }
        }
    }

    private var emptyWatchlist: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: selectedMarket != nil ? "line.3.horizontal.decrease.circle" : "chart.line.uptrend.xyaxis")
                    .font(.system(size: 20))
                    .foregroundColor(.textTertiary)
                Text(selectedMarket != nil
                    ? L10n.stockNoMarketStocks
                    : L10n.stockNoData)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                if selectedMarket == nil {
                    Text(L10n.stockSearchAbove)
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private func watchlistRow(_ item: WatchlistItem) -> some View {
        HStack(spacing: 10) {
            // 股票信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                Text(item.id)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            // 行情数据
            if let quote = stockStore.getQuote(symbol: item.id) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(quote.priceString)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 4) {
                        Text(quote.changePercentString)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(quote.trendSwiftUIColor)
                        if !quote.isFlat {
                            Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(quote.trendSwiftUIColor)
                        }
                    }
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                    Text(item.market.currency)
                        .font(.system(size: 9))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fillSubtle))
    }

    // MARK: - Search Logic

    private func performSearch() {
        searchTask?.cancel()
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let results = try await stockService.searchStocks(keyword: keyword, market: selectedMarket)
                guard !Task.isCancelled else { return }
                searchResults = results
            } catch {
                guard !Task.isCancelled else { return }
                searchResults = []
            }
            isSearching = false
        }
    }
}
