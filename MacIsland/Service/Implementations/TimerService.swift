//
//  TimerService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine

/// 计时器服务 — 番茄钟 + 倒计时
final class TimerService: TimerServiceProtocol, ObservableObject {
    @Published private(set) var pomodoro = PomodoroData()
    @Published private(set) var countdown = CountdownData()

    private var tickTimer: Timer?
    private var onNotification: ((String, String) -> Void)?

    // MARK: - Init

    /// 设置通知回调（由 IslandStore 注入）
    func setNotificationHandler(_ handler: @escaping (String, String) -> Void) {
        self.onNotification = handler
    }

    // MARK: - Pomodoro

    func startPomodoro() {
        pomodoro.running = true
        startTick()
    }

    func pausePomodoro() {
        pomodoro.running = false
        stopTickIfNeeded()
    }

    func resetPomodoro() {
        pomodoro = PomodoroData()
        stopTickIfNeeded()
    }

    func skipPomodoro() {
        advancePomodoroPhase()
    }

    // MARK: - Countdown

    func startCountdown() {
        let total = countdown.totalInputSeconds
        guard total > 0 else { return }
        countdown.state = .running
        countdown.remainingSeconds = total
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
        countdown = CountdownData()
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
            if countdown.remainingSeconds <= 0 {
                countdown.state = .idle
                onNotification?("⏱ 倒计时", "时间到！")
                stopTickIfNeeded()
            }
        }
    }

    // MARK: - Pomodoro Phase Logic

    private func advancePomodoroPhase() {
        let wasWork = pomodoro.phase == .work

        if wasWork {
            pomodoro.completedCount += 1
            let count = pomodoro.completedCount
            if count % 4 == 0 {
                pomodoro.phase = .longBreak
                onNotification?("🍅 专注结束", "休息一下吧，已完成 \(count) 个番茄")
            } else {
                pomodoro.phase = .shortBreak
                onNotification?("🍅 专注结束", "休息 5 分钟")
            }
        } else {
            pomodoro.phase = .work
            onNotification?("🍅 休息结束", "开始专注！")
        }

        pomodoro.remaining = pomodoro.phase.duration
    }
}
