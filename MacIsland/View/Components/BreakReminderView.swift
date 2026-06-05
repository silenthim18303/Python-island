//
//  BreakReminderView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import UserNotifications

// MARK: - Break Reminder View

/// 久坐提醒视图
struct BreakReminderView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var timeSinceLastBreak: TimeInterval = 0
    @State private var timer: Timer?
    @State private var reminderDate = Date()

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 状态显示
            ZStack {
                Circle()
                    .stroke(Color.fillSubtle, lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Text(L10n.breakSeated)
                        .font(.system(size: 9))
                        .foregroundColor(.textQuaternary)
                }
            }

            // 配置
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text(L10n.breakInterval)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Picker("", selection: $settings.breakReminderMinutes) {
                        Text(L10n.break30).tag(30)
                        Text(L10n.break45).tag(45)
                        Text(L10n.break60).tag(60)
                        Text(L10n.break90).tag(90)
                        Text(L10n.break120).tag(120)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .onChange(of: settings.breakReminderMinutes) { _, _ in
                        resetTimer()
                    }
                }

                Toggle(L10n.breakEnable, isOn: $settings.breakReminderEnabled)
                    .onChange(of: settings.breakReminderEnabled) { _, newValue in
                        if newValue { startTimer() } else { stopTimer() }
                    }
            }
            .padding(Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            // 提醒操作
            if timeSinceLastBreak >= TimeInterval(settings.breakReminderMinutes * 60) {
                Button {
                    resetTimer()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(L10n.breakReset)
                    }
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if settings.breakReminderEnabled { startTimer() }
            requestNotificationPermission()
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Progress

    private var progress: CGFloat {
        let total = TimeInterval(settings.breakReminderMinutes * 60)
        return min(timeSinceLastBreak / total, 1.0)
    }

    private var progressColor: Color {
        if progress < 0.5 { return .green }
        if progress < 0.8 { return .orange }
        return .red
    }

    private var formattedTime: String {
        let minutes = Int(timeSinceLastBreak) / 60
        let seconds = Int(timeSinceLastBreak) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        reminderDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeSinceLastBreak = Date().timeIntervalSince(reminderDate)
            if timeSinceLastBreak >= TimeInterval(settings.breakReminderMinutes * 60) {
                sendNotification()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        timeSinceLastBreak = 0
        reminderDate = Date()
    }

    // MARK: - Notification

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🪑 \(L10n.breakTitle)"
        content.body = "\(L10n.breakSeated) \(Int(timeSinceLastBreak / 60)) \(L10n.minutes)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "break-reminder",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
