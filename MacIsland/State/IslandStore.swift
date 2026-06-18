//
//  IslandStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Notifications

extension Notification.Name {
    static let openIslandSettings = Notification.Name("openIslandSettings")
    static let sheetPresented = Notification.Name("sheetPresented")
    static let sheetDismissed = Notification.Name("sheetDismissed")
}

// MARK: - Island Store

/// 灵动岛状态管理
@MainActor
final class IslandStore: ObservableObject {
    // MARK: Published Properties

    @Published private(set) var state: IslandState = .idle

    /// 展开态初始 Tab
    @Published var expandedInitialTab: String?
    /// 最大展开态初始 Tab
    @Published var maxExpandInitialTab: String?

    let settings = AppSettings.shared

    // MARK: Private Properties

    private var idleTimer: AnyCancellable?
    private let idleDelay: TimeInterval = 4.0
    var isSheetPresented = false
    static var isPanelPresented = false
    var isPanelPresented: Bool { Self.isPanelPresented }
    private var cancellables = Set<AnyCancellable>()

    // 当前功能状态（用于计算正确的 idle 变体）
    private var hasMusicContent = false
    private var isPlaying = false
    private var pomodoroActive = false
    private var countdownActive = false
    private weak var timerService: TimerService?
    private weak var clipboardService: ClipboardService?
    private weak var lyricsService: LyricsService?
    private var lastFetchedTitle = ""

    init() {
        NotificationCenter.default.addObserver(forName: .sheetPresented, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSheetPresented = true
            }
        }
        NotificationCenter.default.addObserver(forName: .sheetDismissed, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSheetPresented = false
                guard let self = self else { return }
                if self.state == .expanded || self.state == .maxExpand {
                    self.startIdleTimer(delay: 1.5)
                }
            }
        }
    }

    // MARK: - Bind Services

    func bindTimerService(_ service: TimerService) {
        self.timerService = service
        service.setNotificationHandler { [weak self] title, body in
            DispatchQueue.main.async {
                self?.setNotification(title: title, body: body, source: .timer)
            }
        }

        // 番茄钟状态
        service.$pomodoro
            .receive(on: RunLoop.main)
            .sink { [weak self] pomodoro in
                guard let self = self else { return }
                let active = pomodoro.running || pomodoro.remaining < pomodoro.phaseDuration
                if active != self.pomodoroActive {
                    self.pomodoroActive = active
                    self.syncIdleState()
                }
            }
            .store(in: &cancellables)

        // 倒计时状态
        service.$countdown
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self else { return }
                let active = data.state != .idle
                if active != self.countdownActive {
                    self.countdownActive = active
                    self.syncIdleState()
                }
            }
            .store(in: &cancellables)
    }

    func bindClipboardService(_ service: ClipboardService) {
        self.clipboardService = service
        service.setNotificationHandler { [weak self] title, body, url in
            DispatchQueue.main.async {
                self?.setNotification(title: title, body: body, url: url, source: .clipboard)
            }
        }
    }

    func bindLyricsService(_ service: LyricsService) {
        self.lyricsService = service
    }

    func bindMusicService(_ service: MusicService) {
        Publishers.CombineLatest(service.$hasMedia, service.$info)
            .receive(on: RunLoop.main)
            .sink { [weak self] hasMedia, info in
                guard let self = self else { return }

                let isPlaying = hasMedia && info.isPlaying
                let hasMusicContent = hasMedia && !info.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let changed = hasMusicContent != self.hasMusicContent || isPlaying != self.isPlaying

                self.hasMusicContent = hasMusicContent
                self.isPlaying = isPlaying

                if changed {
                    self.syncIdleState()
                }

                // 歌曲切换时获取歌词
                if hasMedia, info.isPlaying || !info.title.isEmpty {
                    if info.title != self.lastFetchedTitle {
                        self.lastFetchedTitle = info.title
                        Task {
                            await self.lyricsService?.fetchLyrics(
                                title: info.title,
                                artist: info.artist,
                                duration: info.duration
                            )
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func listenForNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openIslandSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setMaxExpand()
            }
        }
    }

    // MARK: - Idle State Computation

    /// 根据当前音乐 / 番茄钟 / 倒计时状态计算正确的 idle 变体
    private func computeIdleState() -> IslandState {
        IslandState.compact(music: hasMusicContent, pomodoro: pomodoroActive, countdown: countdownActive)
    }

    /// 同步 idle 状态 —— 功能状态变化时自动切换到正确的 idle 变体
    /// 仅从缩小态切换，展开/悬停/通知态不干预
    private func syncIdleState() {
        guard state.isCompact else { return }
        let target = computeIdleState()
        guard state != target else { return }
        // 防抖：连续快速变化时只取最后一次
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.state.isCompact else { return }
            let finalTarget = self.computeIdleState()
            guard self.state != finalTarget else { return }
            self.animate(to: finalTarget)
        }
    }

    // MARK: - State Transitions

    func setIdle() {
        let target = computeIdleState()
        guard state != target else { return }
        animate(to: target)
    }

    func setHover() {
        guard canTransitionToHover else { return }
        cancelIdleTimer()
        animate(to: .hover)
    }

    func setExpanded() {
        if state.isCompact {
            expandedInitialTab = L10n.navTools
        }
        cancelIdleTimer()
        animate(to: .expanded)
    }

    func setMaxExpand() {
        cancelIdleTimer()
        animate(to: .maxExpand)
    }

    func setNotification(title: String, body: String, url: String? = nil, source: NotificationSource = .other) {
        NotificationCenterStore.shared.addNotification(title: title, body: body, source: source)
        if AppSettings.shared.isDNDActive { return }
        cancelIdleTimer()
        animate(to: .notification(title: title, body: body, url: url))
        scheduleIdleAfter(3.0)
    }

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

    private var canTransitionToHover: Bool {
        state.isCompact
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
