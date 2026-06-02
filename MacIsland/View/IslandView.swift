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
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                guard IslandLayout.isHeightAdaptive(store.state) else { return }
                IslandWindowManager.shared.updateHeight(height)
            }
            .onAppear {
                store.bindLyricsService(lyricsService)
                store.bindMusicService(musicService)
                store.bindTimerService(timerService)
                store.bindClipboardService(clipboardService)
                IslandWindowManager.shared.onCollapse = { store.setIdle() }
            }
    }

    // MARK: - Private Methods

    private func syncWindowSize(for state: IslandState) {
        DispatchQueue.main.async {
            let size = IslandLayout.size(for: state)
            IslandWindowManager.shared.resize(to: size, state: state)
        }
    }
}
