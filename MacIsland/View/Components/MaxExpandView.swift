//
//  MaxExpandView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Max Expand View

/// 最大展开态视图 — 待办/便签/倒计时/闹钟/书签/AI/设置/工具
struct MaxExpandView: View {
    @ObservedObject var store: IslandStore
    @StateObject private var todoStore = TodoStore.shared
    @StateObject private var memoStore = MemoStore.shared
    @StateObject private var eventStore = EventStore.shared
    @StateObject private var alarmStore = AlarmStore.shared
    @StateObject private var bookmarkStore = BookmarkStore.shared
    @StateObject private var wallpaperStore = WallpaperStore.shared
    @State private var selectedTab: Tab = .todo
    @ObservedObject private var notificationStore = NotificationCenterStore.shared

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case todo = "待办"
        case memo = "便签"
        case event = "倒数日"
        case alarm = "闹钟"
        case bookmark = "书签"
        case wallpaper = "壁纸"
        case ai = "AI"
        case notifications = "通知"
        case settings = "设置"
        case toolbox = "工具"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerBar

            // Tab 选择器
            tabBar

            // 内容区
            ScrollView {
                tabContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            if let tabName = store.maxExpandInitialTab,
               let tab = Tab.allCases.first(where: { $0.rawValue == tabName }) {
                selectedTab = tab
                store.maxExpandInitialTab = nil
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 收起到展开态
            Button { store.setExpanded() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .background(Circle().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
            .help("收起到概览")

            Text("MacIsland")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textPrimary)

            Spacer()

            // 关闭按钮
            Button { store.setIdle() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .background(Circle().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: iconName(for: tab))
                                    .font(.system(size: 14))

                                // 通知角标
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

                            Text(tab.rawValue)
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
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .todo: todoContent
        case .memo: memoContent
        case .event: eventContent
        case .alarm: alarmContent
        case .bookmark: bookmarkContent
        case .wallpaper: wallpaperContent
        case .ai: aiContent
        case .notifications: notificationsContent
        case .settings: settingsContent
        case .toolbox: toolboxContent
        }
    }

    // MARK: - Todo Content

    private var todoContent: some View {
        TodoListView(store: todoStore)
    }

    // MARK: - Memo Content

    private var memoContent: some View {
        MemoListView(store: memoStore)
    }

    // MARK: - Event Content

    private var eventContent: some View {
        EventListView(store: eventStore)
    }

    // MARK: - Alarm Content

    private var alarmContent: some View {
        AlarmListView(store: alarmStore)
    }

    // MARK: - Bookmark Content

    private var bookmarkContent: some View {
        BookmarkListView(store: bookmarkStore)
    }

    // MARK: - Wallpaper Content

    private var wallpaperContent: some View {
        WallpaperView(store: wallpaperStore)
    }

    // MARK: - AI Content

    private var aiContent: some View {
        AIChatView()
    }

    // MARK: - Notifications Content

    private var notificationsContent: some View {
        NotificationCenterView()
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        InlineSettingsView()
    }

    // MARK: - Toolbox Content

    private var toolboxContent: some View {
        ToolboxView()
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
        case .settings: return "gearshape.fill"
        case .toolbox: return "wrench.and.screwdriver.fill"
        }
    }
}

