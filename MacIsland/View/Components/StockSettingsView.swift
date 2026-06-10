//
//  StockSettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

struct StockSettingsView: View {

    @EnvironmentObject var stockService: StockServiceImpl
    @EnvironmentObject var stockStore: StockStore
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(L10n.stockSettings) {
                Toggle(L10n.stockAutoRefresh, isOn: $settings.stockAutoRefresh)
                    .onChange(of: settings.stockAutoRefresh) { _, enabled in
                        if enabled {
                            stockStore.startAutoRefresh(interval: TimeInterval(settings.stockRefreshInterval))
                        } else {
                            stockStore.stopAutoRefresh()
                        }
                    }

                if settings.stockAutoRefresh {
                    Picker(L10n.stockRefreshFreq, selection: $settings.stockRefreshInterval) {
                        Text("1 分钟").tag(60)
                        Text("5 分钟").tag(300)
                        Text("15 分钟").tag(900)
                    }
                    .onChange(of: settings.stockRefreshInterval) { _, newInterval in
                        if settings.stockAutoRefresh {
                            stockStore.startAutoRefresh(interval: TimeInterval(newInterval))
                        }
                    }
                }
            }

            Section(L10n.stockWatchlistManage) {
                NavigationLink(L10n.stockManageWatchlist) {
                    StockListView()
                        .environmentObject(stockStore)
                        .environmentObject(stockService)
                }
            }
        }
        .formStyle(.grouped)
    }
}
