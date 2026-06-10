//
//  MaxExpandView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Max Expand View

/// 最大展开态视图 — 待办/便签/倒计时/闹钟/书签/AI/通知/设置/工具/股票
struct MaxExpandView: View {
    @ObservedObject var store: IslandStore
    @StateObject private var todoStore = TodoStore.shared
    @StateObject private var memoStore = MemoStore.shared
    @StateObject private var eventStore = EventStore.shared
    @StateObject private var alarmStore = AlarmStore.shared
    @StateObject private var bookmarkStore = BookmarkStore.shared
    @StateObject private var wallpaperStore = WallpaperStore.shared
    @EnvironmentObject var stockStore: StockStore
    @EnvironmentObject var stockService: StockServiceImpl
    @State private var selectedTab: Tab = .todo
    @ObservedObject private var notificationStore = NotificationCenterStore.shared
    @ObservedObject private var loc = LocalizationManager.shared

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable, Identifiable {
        case todo = "待办"
        case memo = "便签"
        case event = "倒数日"
        case alarm = "闹钟"
        case bookmark = "书签"
        case wallpaper = "壁纸"
        case ai = "AI"
        case notifications = "通知"
        case toolbox = "工具"
        case stock = "股票"
        case settings = "设置"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .todo: return L10n.tabTodo
            case .memo: return L10n.tabMemo
            case .event: return L10n.tabEvent
            case .alarm: return L10n.tabAlarm
            case .bookmark: return L10n.tabBookmark
            case .ai: return L10n.tabAI
            case .notifications: return L10n.tabNotifications
            case .settings: return L10n.tabSettings
            case .toolbox: return L10n.tabToolbox
            case .wallpaper: return L10n.tabWallpaper
            case .stock: return L10n.stockTitle
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            tabBar

            ScrollView {
                tabContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let tabName = store.maxExpandInitialTab,
               let tab = Tab.allCases.first(where: { $0.rawValue == tabName }) {
                selectedTab = tab
                store.maxExpandInitialTab = nil
            }
        }
        .onKeyPress(.leftArrow) { selectPrevious(); return .handled }
        .onKeyPress(.rightArrow) { selectNext(); return .handled }
    }

    // MARK: - 循环切换

    private func selectNext() {
        let tabs = Tab.allCases
        guard let i = tabs.firstIndex(of: selectedTab) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTab = tabs[(i + 1) % tabs.count]
        }
    }

    private func selectPrevious() {
        let tabs = Tab.allCases
        guard let i = tabs.firstIndex(of: selectedTab) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTab = tabs[(i - 1 + tabs.count) % tabs.count]
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { store.setExpanded() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .background(Circle().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
            .help(L10n.collapseOverview)

            Text(L10n.aboutTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textPrimary)

            Spacer()

            Button { store.setIdle() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .background(Circle().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
            .help(L10n.closePanel)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            // ← 上一个
            Button { selectPrevious() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 20, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tab 滚动栏
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(Tab.allCases) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: iconName(for: tab))
                                            .font(.system(size: 14))

                                        if tab == .notifications && notificationStore.unreadCount > 0 {
                                            Text("\(notificationStore.unreadCount)")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.red))
                                                .offset(x: 8, y: -6)
                                        }
                                    }

                                    Text(tab.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                                .frame(minWidth: 52)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTab == tab
                                        ? RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle)
                                        : nil
                                )
                                .id(tab)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: selectedTab) { _, newTab in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newTab, anchor: .center)
                    }
                }
            }

            // → 下一个
            Button { selectNext() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 20, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .todo: TodoListView(store: todoStore)
            case .memo: MemoListView(store: memoStore)
            case .event: EventListView(store: eventStore)
            case .alarm: AlarmListView(store: alarmStore)
            case .bookmark: BookmarkListView(store: bookmarkStore)
            case .wallpaper: WallpaperView(store: wallpaperStore)
            case .ai: AIChatView()
            case .notifications: NotificationCenterView()
            case .toolbox: ToolboxView()
            case .stock:
                StockListView()
                    .environmentObject(stockStore)
                    .environmentObject(stockService)
            case .settings: InlineSettingsView()
            }
        }
    }

    // MARK: - Helper

    private func iconName(for tab: Tab) -> String {
        switch tab {
        case .todo: return "checklist"
        case .memo: return "note.text"
        case .event: return "calendar.badge.clock"
        case .alarm: return "alarm"
        case .bookmark: return "bookmark.fill"
        case .wallpaper: return "photo.fill"
        case .ai: return "brain.head.profile"
        case .notifications: return "bell.badge.fill"
        case .toolbox: return "wrench.and.screwdriver.fill"
        case .stock: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape.fill"
        }
    }
}
