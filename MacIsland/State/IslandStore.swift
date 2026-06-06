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

    /// 展开态初始 Tab（由 setExpanded() 根据来源形态设置，ExpandedView.onAppear 消费后清空）
    @Published var expandedInitialTab: String?
    /// 最大展开态初始 Tab（由外部通知设置，MaxExpandView.onAppear 消费后清空）
    @Published var maxExpandInitialTab: String?

    /// 共享设置（动画速度 / 弹簧动画）— 设置窗口与岛共用同一数据源
    let settings = AppSettings.shared

    // MARK: Private Properties

    private var previousState: IslandState = .idle
    private var idleTimer: AnyCancellable?
    private let idleDelay: TimeInterval = 4.0
    /// sheet 显示时暂停空闲计时
    var isSheetPresented = false
    /// 系统面板（NSOpenPanel 等）显示时暂停空闲计时（静态，供任意视图设置）
    static var isPanelPresented = false
    /// 当前实例的面板状态（与静态同步）
    var isPanelPresented: Bool { Self.isPanelPresented }
    private var musicSubscriptions = Set<AnyCancellable>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.addObserver(forName: .sheetPresented, object: nil, queue: .main) { [weak self] _ in
            self?.isSheetPresented = true
        }
        NotificationCenter.default.addObserver(forName: .sheetDismissed, object: nil, queue: .main) { [weak self] _ in
            self?.isSheetPresented = false
        }
    }
    private var wasPlaying: Bool = false
    private var wasCountdownActive: Bool = false
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
                self?.setNotification(title: title, body: body, source: .timer)
            }
        }

        // 倒计时自动状态机：歌词优先于倒计时。倒计时后台运行，仅在空闲态时
        // 切入倒计时缩小态；歌词态不被倒计时抢占。
        service.$countdown
            .receive(on: RunLoop.main)
            .sink { [weak self] data in
                guard let self = self else { return }
                let active = data.state == .running || data.state == .completed
                // 进入：仅从空闲态切入（不抢占歌词态）
                if active && !self.wasCountdownActive && self.state == .idle {
                    self.setCountdown()
                }
                // 退出：倒计时回到 idle（重置）且当前仍在倒计时态
                if !active && self.wasCountdownActive && self.state == .countdown {
                    self.wasPlaying ? self.setLyrics() : self.setIdle()
                }
                self.wasCountdownActive = active
            }
            .store(in: &musicSubscriptions)
    }

    /// Bind clipboard service — wire notification callback
    func bindClipboardService(_ service: ClipboardService) {
        self.clipboardService = service
        service.setNotificationHandler { [weak self] title, body in
            DispatchQueue.main.async {
                self?.setNotification(title: title, body: body, source: .clipboard)
            }
        }
    }

    /// 监听外部通知，打开设置标签
    func listenForNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openIslandSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setMaxExpand()
            self?.maxExpandInitialTab = L10n.navSettings
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

                // Music started playing while idle or countdown -> switch to lyrics（歌词优先）
                if isPlaying && !self.wasPlaying && (self.state == .idle || self.state == .countdown) {
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
        // 从倒计时态展开时，自动切到工具 Tab
        if state == .countdown {
            expandedInitialTab = L10n.navTools
        }
        previousState = state
        cancelIdleTimer()
        animate(to: .expanded)
    }

    func setMaxExpand() {
        previousState = state
        cancelIdleTimer()
        animate(to: .maxExpand)
    }

    func setNotification(title: String, body: String, source: NotificationSource = .other) {
        // 保存到通知历史（无论是否显示）
        NotificationCenterStore.shared.addNotification(title: title, body: body, source: source)

        // 免打扰时段内不显示灵动岛通知
        if AppSettings.shared.isDNDActive { return }

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
