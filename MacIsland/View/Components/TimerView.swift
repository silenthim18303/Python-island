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
        case pomodoro = "番茄钟"
        case countdown = "倒计时"
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

    var body: some View {
        let data = timerService.pomodoro

        VStack(spacing: 8) {
            // Progress ring + time
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

                // Completed count
                VStack(spacing: 2) {
                    Text("\(data.completedCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("完成")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Controls
            HStack(spacing: 12) {
                if data.running {
                    TimerButton(title: "暂停", icon: "pause.fill") {
                        timerService.pausePomodoro()
                    }
                } else {
                    TimerButton(title: "开始", icon: "play.fill") {
                        timerService.startPomodoro()
                    }
                }

                TimerButton(title: "重置", icon: "arrow.counterclockwise") {
                    timerService.resetPomodoro()
                }

                TimerButton(title: "跳过", icon: "forward.fill") {
                    timerService.skipPomodoro()
                }
            }
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
    @State private var editing = false
    @State private var inputH = 0
    @State private var inputM = 5
    @State private var inputS = 0

    var body: some View {
        let data = timerService.countdown

        VStack(spacing: 8) {
            if data.state == .idle && !editing {
                countdownInput
            } else {
                Text(data.state == .idle ? data.formattedInput : data.formattedRemaining)
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
                    if editing {
                        TimerButton(title: "开始", icon: "play.fill") {
                            timerService.setCountdownInput(hours: inputH, minutes: inputM, seconds: inputS)
                            timerService.startCountdown()
                            editing = false
                        }
                        TimerButton(title: "取消", icon: "xmark") {
                            editing = false
                        }
                    } else {
                        TimerButton(title: "设置", icon: "slider.horizontal.3") {
                            inputH = data.inputHours
                            inputM = data.inputMinutes
                            inputS = data.inputSeconds
                            editing = true
                        }
                    }
                case .running:
                    TimerButton(title: "暂停", icon: "pause.fill") {
                        timerService.pauseCountdown()
                    }
                    TimerButton(title: "重置", icon: "arrow.counterclockwise") {
                        timerService.resetCountdown()
                        editing = false
                    }
                case .paused:
                    TimerButton(title: "继续", icon: "play.fill") {
                        timerService.resumeCountdown()
                    }
                    TimerButton(title: "重置", icon: "arrow.counterclockwise") {
                        timerService.resetCountdown()
                        editing = false
                    }
                }
            }
        }
    }

    private var countdownInput: some View {
        HStack(spacing: 4) {
            StepperField(value: $inputH, range: 0...23, label: "时")
            Text(":").foregroundColor(.white.opacity(0.5))
            StepperField(value: $inputM, range: 0...59, label: "分")
            Text(":").foregroundColor(.white.opacity(0.5))
            StepperField(value: $inputS, range: 0...59, label: "秒")
        }
    }
}

// MARK: - Stepper Field

private struct StepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Button {
                value = min(value + 1, range.upperBound)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Text(String(format: "%02d", value))
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 28)

            Button {
                value = max(value - 1, range.lowerBound)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
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
