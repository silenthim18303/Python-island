//
//  StockMiniCard.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

/// 概览页的股票迷你卡片 — 与天气卡片风格统一
struct StockMiniCard: View {
    @EnvironmentObject var stockStore: StockStore
    @EnvironmentObject var stockService: StockServiceImpl

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                Text(L10n.stockWatchlist)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(stockStore.watchlist.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            if stockStore.watchlist.isEmpty {
                Text(L10n.stockNoData)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                // 最多显示 3 只
                ForEach(stockStore.watchlist.prefix(3)) { item in
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        if let quote = stockStore.getQuote(symbol: item.id) {
                            Text(quote.priceString)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(quote.changePercentString)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(quote.trendSwiftUIColor)
                        } else {
                            Text("—")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
    }
}
