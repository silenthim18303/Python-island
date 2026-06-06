//
//  TimerView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Timer View

/// 工具 tab — 番茄钟 + 倒计时
struct TimerView: View {
    @EnvironmentObject var timerService: TimerService

    @State private var mode: Mode = .pomodoro

    enum Mode: String, CaseIterable {
        case pomodoro = "pomodoro"
        case countdown = "countdown"
    }

    var body: some View {
        VStack(spacing: 10) {
            // Mode picker
            modePicker

            if mode == .pomodoro {
                PomodoroSection(timerService: timerService)
            } else {
                CountdownSection(timerService: timerService)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 11, weight: mode == m ? .semibold : .medium))
                        .foregroundColor(mode == m ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            mode == m
                                ? Capsule().fill(.white.opacity(0.15))
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Pomodoro Section

private struct PomodoroSection: View {
    @ObservedObject var timerService: TimerService
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let data = timerService.pomodoro

        VStack(spacing: 8) {
            if data.running {
                // 运行中：进度环 + 时间 + 完成数
                runningUI(data: data)
            } else {
                // 未运行：阶段选择 + 时长调整
                idleUI(data: data)
            }

            // Controls
            HStack(spacing: 12) {
                if data.running {
                    TimerButton(title: L10n.timerPause, icon: "pause.fill") {
                        timerService.pausePomodoro()
                    }
                } else {
                    TimerButton(title: L10n.timerStart, icon: "play.fill") {
                        timerService.startPomodoro()
                    }
                }

                TimerButton(title: L10n.reset, icon: "arrow.counterclockwise") {
                    timerService.resetPomodoro()
                }

                TimerButton(title: L10n.close, icon: "forward.fill") {
                    timerService.skipPomodoro()
                }
            }
        }
        // 空闲态下设置变化时同步剩余时间
        .onChange(of: settings.pomodoroWorkMinutes) { _ in syncDurationIfIdle(.work) }
        .onChange(of: settings.pomodoroShortBreakMinutes) { _ in syncDurationIfIdle(.shortBreak) }
        .onChange(of: settings.pomodoroLongBreakMinutes) { _ in syncDurationIfIdle(.longBreak) }
    }

    /// 设置变化时同步当前选中阶段的剩余时间
    private func syncDurationIfIdle(_ changedPhase: PomodoroPhase) {
        guard !timerService.pomodoro.running else { return }
        guard timerService.pomodoro.phase == changedPhase else { return }
        timerService.selectPomodoroPhase(changedPhase)
    }

    // MARK: - 运行中 UI

    private func runningUI(data: PomodoroData) -> some View {
        HStack(spacing: 14) {
            PomodoroRing(progress: data.progress, phase: data.phase)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.formattedTime)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text(data.phase.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(phaseColor(data.phase).opacity(0.8))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(data.completedCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(L10n.done)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - 未运行 UI（阶段选择 + 时长调整）

    private func idleUI(data: PomodoroData) -> some View {
        VStack(spacing: 6) {
            // 阶段选择器：专注 / 短休 / 长休
            phasePicker(data: data)

            // 选中阶段的时长调整
            switch data.phase {
            case .work:
                durationRow(title: L10n.timerWork, color: .red, value: $settings.pomodoroWorkMinutes, range: 1...120)
            case .shortBreak:
                durationRow(title: L10n.timerBreak, color: .green, value: $settings.pomodoroShortBreakMinutes, range: 1...30)
            case .longBreak:
                durationRow(title: L10n.timerLongBreak, color: .blue, value: $settings.pomodoroLongBreakMinutes, range: 1...60)
            }
        }
    }

    /// 阶段轮选器
    private func phasePicker(data: PomodoroData) -> some View {
        HStack(spacing: 2) {
            ForEach(PomodoroPhase.allCases, id: \.self) { phase in
                let selected = data.phase == phase
                let color = phaseColor(phase)
                let minutes: Int = {
                    switch phase {
                    case .work: return settings.pomodoroWorkMinutes
                    case .shortBreak: return settings.pomodoroShortBreakMinutes
                    case .longBreak: return settings.pomodoroLongBreakMinutes
                    }
                }()

                Button {
                    timerService.selectPomodoroPhase(phase)
                } label: {
                    VStack(spacing: 2) {
                        Text(phase.rawValue)
                            .font(.system(size: 10, weight: selected ? .bold : .medium))
                        Text("\(minutes) \(L10n.timerMin)")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(selected ? color.opacity(0.3) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        Capsule().stroke(selected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundColor(selected ? .white : .white.opacity(0.5))
            }
        }
        .padding(.horizontal, 2)
    }

    /// 时长调整行（纯 StepperField）
    private func durationRow(title: String, color: Color, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color.opacity(0.8))
                .frame(width: 28, alignment: .leading)

            Text(L10n.timerMin)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.35))

            Spacer()

            StepperField(value: value, range: range, label: "min")
        }
    }

    private func phaseColor(_ phase: PomodoroPhase) -> Color {
        switch phase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

// MARK: - Pomodoro Ring

private struct PomodoroRing: View {
    let progress: Double
    let phase: PomodoroPhase

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }

    private var ringColor: Color {
        switch phase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

// MARK: - Countdown Section

private struct CountdownSection: View {
    @ObservedObject var timerService: TimerService
    @State private var inputH = 0
    @State private var inputM = 5
    @State private var inputS = 0

    var body: some View {
        let data = timerService.countdown

        VStack(spacing: 8) {
            if data.state == .idle {
                // 空闲态：预设 + StepperField + 直接开始
                countdownInput
            } else if data.state == .completed {
                // 时间到提示
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text(L10n.alarmTimeUp)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Text(data.formattedRemaining)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                if data.state == .running {
                    ProgressView(value: data.progress, total: 1.0)
                        .tint(.white)
                        .padding(.horizontal, 20)
                }
            }

            HStack(spacing: 12) {
                switch data.state {
                case .idle:
                    TimerButton(title: L10n.timerStart, icon: "play.fill") {
                        timerService.setCountdownInput(hours: inputH, minutes: inputM, seconds: inputS)
                        timerService.startCountdown()
                    }
                case .running:
                    TimerButton(title: L10n.timerPause, icon: "pause.fill") {
                        timerService.pauseCountdown()
                    }
                    TimerButton(title: L10n.reset, icon: "arrow.counterclockwise") {
                        timerService.resetCountdown()
                    }
                case .paused:
                    TimerButton(title: "继续", icon: "play.fill") {
                        timerService.resumeCountdown()
                    }
                    TimerButton(title: L10n.reset, icon: "arrow.counterclockwise") {
                        timerService.resetCountdown()
                    }
                case .completed:
                    TimerButton(title: L10n.reset, icon: "arrow.counterclockwise") {
                        timerService.resetCountdown()
                    }
                }
            }
        }
    }

    private var countdownInput: some View {
        VStack(spacing: 8) {
            // 常用预设按钮
            HStack(spacing: 6) {
                ForEach([1, 3, 5, 10, 15, 25, 30], id: \.self) { min in
                    Button {
                        inputH = 0; inputM = min; inputS = 0
                    } label: {
                        Text("\(min)m")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 时:分:秒 StepperField
            HStack(spacing: 4) {
                StepperField(value: $inputH, range: 0...23, label: "时")
                Text(":").foregroundColor(.white.opacity(0.5))
                StepperField(value: $inputM, range: 0...59, label: "分")
                Text(":").foregroundColor(.white.opacity(0.5))
                StepperField(value: $inputS, range: 0...59, label: "秒")
            }
        }
    }
}

// MARK: - Stepper Field

private struct StepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String

    @State private var isPressingUp = false
    @State private var isPressingDown = false
    @State private var repeatTimer: Timer?

    var body: some View {
        VStack(spacing: 1) {
            // 上按钮（点击 + 长按连续递增）
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(isPressingUp ? 0.9 : 0.5))
                .frame(width: 32, height: 22)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                    handlePress(pressing: pressing, isUp: true)
                }, perform: {})

            // 数字
            Text(String(format: "%02d", value))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 28)

            // 下按钮（点击 + 长按连续递减）
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(isPressingDown ? 0.9 : 0.5))
                .frame(width: 32, height: 22)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                    handlePress(pressing: pressing, isUp: false)
                }, perform: {})
        }
    }

    private func handlePress(pressing: Bool, isUp: Bool) {
        if pressing {
            if isUp { isPressingUp = true; increment() }
            else { isPressingDown = true; decrement() }
            // 300ms 后开始连续触发（每秒 10 次）
            repeatTimer?.invalidate()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    isUp ? increment() : decrement()
                }
            }
        } else {
            isPressingUp = false
            isPressingDown = false
            repeatTimer?.invalidate()
            repeatTimer = nil
        }
    }

    private func increment() {
        value = value >= range.upperBound ? range.lowerBound : value + 1
    }

    private func decrement() {
        value = value <= range.lowerBound ? range.upperBound : value - 1
    }
}

// MARK: - Timer Button

private struct TimerButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.white.opacity(isHovering ? 0.9 : 0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(.white.opacity(isHovering ? 0.15 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
