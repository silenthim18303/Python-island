//
//  TimerServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Timer Models

/// 番茄钟阶段
enum PomodoroPhase: String, CaseIterable, Hashable {
    case work = "专注"
    case shortBreak = "短休"
    case longBreak = "长休"

    /// 硬编码默认值，仅作兜底
    var defaultDuration: Int {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }

    /// 从 AppSettings 读取当前设置的时长
    func durationFromSettings(_ settings: AppSettings) -> Int {
        switch self {
        case .work: return settings.pomodoroWorkMinutes * 60
        case .shortBreak: return settings.pomodoroShortBreakMinutes * 60
        case .longBreak: return settings.pomodoroLongBreakMinutes * 60
        }
    }
}

/// 倒计时状态
enum CountdownTimerState: String {
    case idle       // 未启动（输入界面）
    case running    // 计时中
    case paused     // 已暂停
    case completed  // 已完成（显示"时间到"提示）
}

/// 番茄钟数据
struct PomodoroData {
    var phase: PomodoroPhase = .work
    var remaining: Int = PomodoroPhase.work.defaultDuration
    var running: Bool = false
    var completedCount: Int = 0
    /// 当前阶段的总时长快照（秒），由 TimerService 在阶段切换时从设置注入
    var phaseDuration: Int = PomodoroPhase.work.defaultDuration

    /// 从 AppSettings 创建初始数据（使用用户设置的时长）
    static func fromSettings(_ settings: AppSettings) -> PomodoroData {
        let duration = PomodoroPhase.work.durationFromSettings(settings)
        return PomodoroData(remaining: duration, phaseDuration: duration)
    }

    var progress: Double {
        guard phaseDuration > 0 else { return 0 }
        return 1.0 - Double(max(remaining, 0)) / Double(phaseDuration)
    }

    var formattedTime: String {
        let clamped = max(remaining, 0)
        let m = clamped / 60
        let s = clamped % 60
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

    /// 启动时快照的总时长（秒），用于进度计算，避免输入值被修改后进度越界
    var totalDuration: Int = 0

    var totalInputSeconds: Int {
        inputHours * 3600 + inputMinutes * 60 + inputSeconds
    }

    var formattedRemaining: String {
        let clamped = max(remainingSeconds, 0)
        let h = clamped / 3600
        let m = (clamped % 3600) / 60
        let s = clamped % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// 输入态格式化 — 与 formattedRemaining 统一：小时为 0 时用 m:ss
    var formattedInput: String {
        let total = totalInputSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - Double(max(remainingSeconds, 0)) / Double(totalDuration)
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
    func selectPomodoroPhase(_ phase: PomodoroPhase)

    // Countdown
    func startCountdown()
    func pauseCountdown()
    func resumeCountdown()
    func resetCountdown()
    func setCountdownInput(hours: Int, minutes: Int, seconds: Int)
}
