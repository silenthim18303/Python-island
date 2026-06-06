//
//  TimerService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine
import Combine
import AppKit

/// 计时器服务 — 番茄钟 + 倒计时（可同时运行，共享 tick Timer）
final class TimerService: TimerServiceProtocol, ObservableObject {
    @Published private(set) var pomodoro = PomodoroData.fromSettings(AppSettings.shared)
    @Published private(set) var countdown = CountdownData()

    private var tickTimer: Timer?
    private var onNotification: ((String, String) -> Void)?
    /// 已触发的倒计时提醒时间点（避免重复提醒）
    private var firedReminders: Set<Int> = []
    /// 倒计时提前提醒时间点（秒）
    private let reminderTimePoints: Set<Int> = [1800, 600, 300, 60, 30, 10, 5, 4, 3, 2, 1]

    // MARK: - Init

    init() {
        // 订阅计时器状态变化，更新小组件数据
        $pomodoro.combineLatest($countdown)
            .receive(on: RunLoop.main)
            .sink { [weak self] pomodoro, countdown in
                self?.updateWidgetData(pomodoro: pomodoro, countdown: countdown)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    deinit {
        tickTimer?.invalidate()
    }

    private func updateWidgetData(pomodoro: PomodoroData, countdown: CountdownData) {
        if pomodoro.running {
            WidgetDataManager.shared.updateTimer(
                type: "pomodoro",
                remainingSeconds: pomodoro.remaining,
                isRunning: true,
                completedPomodoros: pomodoro.completedCount
            )
        } else if countdown.state == .running {
            WidgetDataManager.shared.updateTimer(
                type: "countdown",
                remainingSeconds: countdown.remainingSeconds,
                isRunning: true,
                completedPomodoros: pomodoro.completedCount
            )
        } else {
            WidgetDataManager.shared.updateTimer(
                type: "idle",
                remainingSeconds: 0,
                isRunning: false,
                completedPomodoros: pomodoro.completedCount
            )
        }
    }

    /// 设置通知回调（由 IslandStore 注入）
    func setNotificationHandler(_ handler: @escaping (String, String) -> Void) {
        self.onNotification = handler
    }

    // MARK: - Pomodoro

    func startPomodoro() {
        let duration = pomodoroDuration(for: pomodoro.phase)
        pomodoro.phaseDuration = duration
        pomodoro.remaining = duration
        pomodoro.running = true
        startTick()
    }

    func pausePomodoro() {
        pomodoro.running = false
        stopTickIfNeeded()
    }

    func resetPomodoro() {
        let savedCount = pomodoro.completedCount
        pomodoro = PomodoroData.fromSettings(AppSettings.shared)
        pomodoro.completedCount = savedCount
        stopTickIfNeeded()
    }

    func skipPomodoro() {
        let wasRunning = pomodoro.running
        advancePomodoroPhase()
        // 跳过后若之前在运行，重启 timer 以同步节奏（修复 H1: 双倍 tick）
        if wasRunning {
            stopTickIfNeeded()
            startTick()
        }
    }

    func selectPomodoroPhase(_ phase: PomodoroPhase) {
        guard !pomodoro.running else { return }
        pomodoro.phase = phase
        let duration = pomodoroDuration(for: phase)
        pomodoro.phaseDuration = duration
        pomodoro.remaining = duration
    }

    // MARK: - Countdown

    func startCountdown() {
        let total = countdown.totalInputSeconds
        guard total > 0 else { return }
        countdown.state = .running
        countdown.remainingSeconds = total
        // 快照总时长，用于进度计算（修复 H5: 输入值变化导致进度越界）
        countdown.totalDuration = total
        firedReminders = []
        startTick()
    }

    func pauseCountdown() {
        countdown.state = .paused
        stopTickIfNeeded()
    }

    func resumeCountdown() {
        countdown.state = .running
        startTick()
    }

    func resetCountdown() {
        // 保留用户上次设定的输入时间，仅重置计时状态
        let h = countdown.inputHours
        let m = countdown.inputMinutes
        let s = countdown.inputSeconds
        countdown = CountdownData()
        countdown.inputHours = h
        countdown.inputMinutes = m
        countdown.inputSeconds = s
        firedReminders = []
        stopTickIfNeeded()
    }

    func setCountdownInput(hours: Int, minutes: Int, seconds: Int) {
        countdown.inputHours = min(max(hours, 0), 23)
        countdown.inputMinutes = min(max(minutes, 0), 59)
        countdown.inputSeconds = min(max(seconds, 0), 59)
    }

    // MARK: - Tick

    private func startTick() {
        stopTickIfNeeded()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTickIfNeeded() {
        let needsStop = !pomodoro.running && countdown.state != .running
        if needsStop {
            tickTimer?.invalidate()
            tickTimer = nil
        }
    }

    private func tick() {
        // Pomodoro tick
        if pomodoro.running && pomodoro.remaining > 0 {
            pomodoro.remaining -= 1
            if pomodoro.remaining <= 0 {
                advancePomodoroPhase()
            }
        }

        // Countdown tick
        if countdown.state == .running && countdown.remainingSeconds > 0 {
            countdown.remainingSeconds -= 1

            // 提前提醒：命中时间点时发送通知（不中断倒计时）
            let remaining = countdown.remainingSeconds
            if reminderTimePoints.contains(remaining) && !firedReminders.contains(remaining) {
                firedReminders.insert(remaining)
                let label = formatReminderLabel(remaining)
                onNotification?(L10n.timerNotifCountdown, "\(L10n.timerNotifTimeUp) \(label)")
            }

            if countdown.remainingSeconds <= 0 {
                countdown.state = .completed
                onNotification?(L10n.timerNotifTimeUp, L10n.alarmTimeUp)
                stopTickIfNeeded()
            }
        }
    }

    // MARK: - Pomodoro Phase Logic

    private func advancePomodoroPhase() {
        let settings = AppSettings.shared
        let wasWork = pomodoro.phase == .work

        if wasWork {
            pomodoro.completedCount += 1
            let count = pomodoro.completedCount
            if count % settings.pomodoroLongBreakInterval == 0 {
                pomodoro.phase = .longBreak
                onNotification?(L10n.timerNotifFocusEnd, "\(L10n.timerNotifRest) \(count) \(L10n.timerPomodoro)")
            } else {
                pomodoro.phase = .shortBreak
                onNotification?(L10n.timerNotifFocusEnd, "\(L10n.timerBreak) \(settings.pomodoroShortBreakMinutes) \(L10n.minutes)")
            }
        } else {
            pomodoro.phase = .work
            onNotification?(L10n.timerNotifBreakEnd, "\(L10n.timerStart)!")
        }

        let duration = pomodoroDuration(for: pomodoro.phase)
        pomodoro.phaseDuration = duration
        pomodoro.remaining = duration
    }

    /// 根据 AppSettings 获取指定阶段的时长（秒）
    private func pomodoroDuration(for phase: PomodoroPhase) -> Int {
        let settings = AppSettings.shared
        switch phase {
        case .work:       return settings.pomodoroWorkMinutes * 60
        case .shortBreak: return settings.pomodoroShortBreakMinutes * 60
        case .longBreak:  return settings.pomodoroLongBreakMinutes * 60
        }
    }

    // MARK: - Reminder Label

    /// 格式化提醒时间标签
    private func formatReminderLabel(_ seconds: Int) -> String {
        if seconds >= 3600 { return "\(seconds / 3600)小时" }
        if seconds >= 60  { return "\(seconds / 60)分钟" }
        return "\(seconds)秒"
    }
}
