//
//  IslandStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Island Store

/// 灵动岛状态管理
@MainActor
final class IslandStore: ObservableObject {
    // MARK: Published Properties

    @Published private(set) var state: IslandState = .idle

    /// 共享设置（动画速度 / 弹簧动画）— 设置窗口与岛共用同一数据源
    let settings = AppSettings.shared

    // MARK: Private Properties

    private var previousState: IslandState = .idle
    private var idleTimer: AnyCancellable?
    private let idleDelay: TimeInterval = 4.0
    private var musicSubscriptions = Set<AnyCancellable>()
    private var wasPlaying: Bool = false
    private var wasCountingDown: Bool = false
    private weak var lyricsService: LyricsService?
    private weak var timerService: TimerService?
    private weak var clipboardService: ClipboardService?
    private var lastFetchedTitle: String = ""

    // MARK: - Music Integration

    /// Bind lyrics service for auto-fetch on song change
    func bindLyricsService(_ service: LyricsService) {
        self.lyricsService = service
    }

    /// Bind timer service — wire notification callback & countdown auto-state
    func bindTimerService(_ service: TimerService) {
        self.timerService = service
        service.setNotificationHandler { [weak self] title, body in
            DispatchQueue.main.async {
                self?.setNotification(title: title, body: body)
            }
        }

        // 倒计时自动状态机：running 时进入横向倒计时态（优先于歌词），结束/重置后
        // 回到歌词（音乐在播）或空闲。wasCountingDown 记录上一次 running，用于只在
        // running 状态翻转的边沿触发切换，避免每秒 tick 都重复进入。
        service.$countdown
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self else { return }
                let running = data.state == .running
                // 进入：仅当从非 running 翻转为 running，且当前处于可被覆盖的缩小态
                if running && !self.wasCountingDown && (self.state == .idle || self.state == .lyrics) {
                    self.setCountdown()
                }
                // 退出：倒计时结束/暂停且当前仍停留在倒计时态
                if !running && self.wasCountingDown && self.state == .countdown {
                    self.wasPlaying ? self.setLyrics() : self.setIdle()
                }
                self.wasCountingDown = running
            }
            .store(in: &musicSubscriptions)
    }

    /// Bind clipboard service — wire notification callback
    func bindClipboardService(_ service: ClipboardService) {
        self.clipboardService = service
        service.setNotificationHandler { [weak self] title, body in
            DispatchQueue.main.async {
                self?.setNotification(title: title, body: body)
            }
        }
    }

    /// Bind music service for auto-lyrics state transitions
    func bindMusicService(_ musicService: SystemMusicService) {
        musicService.$hasMedia
            .combineLatest(musicService.$info)
            .receive(on: RunLoop.main)
            .sink { [weak self] hasMedia, info in
                guard let self = self else { return }
                let isPlaying = hasMedia && info.isPlaying

                // Music started playing while idle -> switch to lyrics
                if isPlaying && !self.wasPlaying && self.state == .idle {
                    self.setLyrics()
                }
                // Music stopped while in lyrics -> switch to idle
                if !isPlaying && self.wasPlaying && self.state == .lyrics {
                    self.setIdle()
                }

                // Auto-fetch lyrics on song change (not on every interpolation tick)
                if hasMedia && !info.title.isEmpty && info.title != self.lastFetchedTitle {
                    self.lastFetchedTitle = info.title
                    let title = info.title
                    let artist = info.artist
                    let duration = info.duration
                    Task { [weak self] in
                        await self?.lyricsService?.fetchLyrics(title: title, artist: artist, duration: duration)
                    }
                } else if !hasMedia {
                    self.lastFetchedTitle = ""
                    self.lyricsService?.clearLyrics()
                }

                self.wasPlaying = isPlaying
            }
            .store(in: &musicSubscriptions)
    }

    // MARK: - State Transitions

    func setIdle() {
        guard state != .idle else { return }
        previousState = state
        animate(to: .idle)
    }

    func setHover() {
        guard canTransitionToHover else { return }
        previousState = state
        cancelIdleTimer()
        animate(to: .hover)
    }

    func setExpanded() {
        previousState = state
        cancelIdleTimer()
        animate(to: .expanded)
    }

    func setMaxExpand() {
        previousState = state
        cancelIdleTimer()
        animate(to: .maxExpand)
    }

    func setNotification(title: String, body: String) {
        previousState = state
        cancelIdleTimer()
        animate(to: .notification(title: title, body: body))
        scheduleIdleAfter(3.0)
    }

    func setLyrics() {
        previousState = state
        cancelIdleTimer()
        animate(to: .lyrics)
    }

    func setCountdown() {
        previousState = state
        cancelIdleTimer()
        animate(to: .countdown)
    }

    // MARK: - Idle Timer

    func startIdleTimer(delay: TimeInterval? = nil) {
        cancelIdleTimer()
        idleTimer = Just(())
            .delay(for: .seconds(delay ?? idleDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.setIdle() }
    }

    func cancelIdleTimer() {
        idleTimer?.cancel()
        idleTimer = nil
    }

    // MARK: - Private Helpers

    /// 仅缩小态（空闲 / 歌词 / 倒计时）允许悬停展开，其余态不响应 hover
    private var canTransitionToHover: Bool {
        state == .idle || state == .lyrics || state == .countdown
    }

    private func scheduleIdleAfter(_ delay: TimeInterval) {
        startIdleTimer(delay: delay)
    }

    private func animate(to newState: IslandState) {
        withAnimation(.spring(response: settings.animationSpeed.duration, dampingFraction: 0.75)) {
            state = newState
        }
    }
}
