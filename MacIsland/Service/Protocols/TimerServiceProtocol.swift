//
//  TimerServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Timer Models

/// 番茄钟阶段
enum PomodoroPhase: String, CaseIterable {
    case work = "专注"
    case shortBreak = "短休"
    case longBreak = "长休"

    var duration: Int {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }

    var color: String {
        switch self {
        case .work: return "red"
        case .shortBreak: return "green"
        case .longBreak: return "blue"
        }
    }
}

/// 倒计时状态
enum CountdownTimerState: String {
    case idle
    case running
    case paused
}

/// 番茄钟数据
struct PomodoroData {
    var phase: PomodoroPhase = .work
    var remaining: Int = 25 * 60
    var running: Bool = false
    var completedCount: Int = 0

    var progress: Double {
        guard phase.duration > 0 else { return 0 }
        return 1.0 - Double(remaining) / Double(phase.duration)
    }

    var formattedTime: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// 倒计时数据
struct CountdownData {
    var state: CountdownTimerState = .idle
    var remainingSeconds: Int = 0
    var inputHours: Int = 0
    var inputMinutes: Int = 5
    var inputSeconds: Int = 0

    var totalInputSeconds: Int {
        inputHours * 3600 + inputMinutes * 60 + inputSeconds
    }

    var formattedRemaining: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedInput: String {
        String(format: "%02d:%02d:%02d", inputHours, inputMinutes, inputSeconds)
    }

    var progress: Double {
        let total = totalInputSeconds
        guard total > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(total)
    }
}

// MARK: - Timer Service Protocol

protocol TimerServiceProtocol: AnyObject {
    var pomodoro: PomodoroData { get }
    var countdown: CountdownData { get }

    // Pomodoro
    func startPomodoro()
    func pausePomodoro()
    func resetPomodoro()
    func skipPomodoro()

    // Countdown
    func startCountdown()
    func pauseCountdown()
    func resumeCountdown()
    func resetCountdown()
    func setCountdownInput(hours: Int, minutes: Int, seconds: Int)
}
