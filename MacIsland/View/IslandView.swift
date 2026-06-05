//
//  IslandView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Island View

/// 灵动岛主视图
struct IslandView: View {
    @StateObject private var store = IslandStore()
    @EnvironmentObject var musicService: SystemMusicService
    @EnvironmentObject var lyricsService: LyricsService
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var clipboardService: ClipboardService
    @EnvironmentObject var hotkeyService: HotkeyService
    @State private var lastReportedHeight: CGFloat = 0

    var body: some View {
        CapsuleShell(store: store)
            .animation(
                store.settings.springAnimation
                    ? .spring(response: store.settings.animationSpeed.duration, dampingFraction: 0.75)
                    : .easeInOut(duration: store.settings.animationSpeed.duration),
                value: store.state
            )
            .onChange(of: store.state) { _, newState in
                syncWindowSize(for: newState)
            }
            .onChange(of: hotkeyService.isAccessibilityGranted) { _, granted in
                // 权限从「未授予」变为「已授予」时，通知用户快捷键已可用
                if granted {
                    store.setNotification(title: "⌨️ 快捷键已启用", body: "⌥⌘I/P/←/→ 现在可用", source: .system)
                }
            }
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                guard IslandLayout.isHeightAdaptive(store.state) else { return }
                // 防抖：高度变化超过 2pt 才更新，避免布局递归
                guard abs(height - lastReportedHeight) > 2 else { return }
                lastReportedHeight = height
                IslandWindowManager.shared.updateHeight(height)
            }
            .onChange(of: store.settings.islandOpacity) { _, newValue in
                IslandWindowManager.shared.setOpacity(newValue)
            }
            .onAppear {
                store.bindLyricsService(lyricsService)
                store.bindMusicService(musicService)
                store.bindTimerService(timerService)
                store.bindClipboardService(clipboardService)
                store.listenForNotifications()
                IslandWindowManager.shared.onCollapse = { store.setIdle() }

                // 应用透明度设置
                IslandWindowManager.shared.setOpacity(store.settings.islandOpacity)

                // 启动后检查辅助功能权限，不足时以通知态提醒用户
                if !hotkeyService.isAccessibilityGranted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        store.setNotification(title: "⌨️ 快捷键不可用", body: "请在设置中授权辅助功能权限", source: .system)
                    }
                }
            }
    }

    // MARK: - Private Methods

    private func syncWindowSize(for state: IslandState) {
        let size = IslandLayout.size(for: state)
        IslandWindowManager.shared.resize(to: size, state: state)
    }
}
