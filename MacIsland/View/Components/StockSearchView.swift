//
//  StockSearchView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

struct StockSearchView: View {

    @EnvironmentObject var stockService: StockServiceImpl
    @EnvironmentObject var stockStore: StockStore
    @State private var searchText = ""
    @State private var searchResults: [StockItem] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                TextField(L10n.stockSearch, text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(L10n.stockSearchAction) { performSearch() }
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding()

            // 错误提示
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // 搜索结果
            if hasSearched && searchResults.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text(L10n.stockNoResults)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            } else {
                List(searchResults) { stock in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stock.name)
                            HStack(spacing: 4) {
                                Text(stock.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(stock.market.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
                }
            }
        }
        .frame(minWidth: 360, minHeight: 300)
    }

    private func performSearch() {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        hasSearched = true

        Task {
            do {
                searchResults = try await stockService.searchStocks(keyword: keyword, market: nil)
            } catch {
                searchResults = []
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}
