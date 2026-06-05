//
//  AlarmListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Alarm List View

/// 闹钟列表视图
struct AlarmListView: View {
    @ObservedObject var store: AlarmStore
    @ObservedObject private var settings = AppSettings.shared

    @State private var showAddAlarm = false
    @State private var newLabel = ""
    @State private var newHour = 8
    @State private var newMinute = 0
    @State private var newRepeatDays: Set<Weekday> = []

    var body: some View {
        if store.sortedItems.isEmpty && !showAddAlarm {
            onboardingView
        } else {
            alarmListView
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "alarm")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text(L10n.alarmTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(L10n.alarmSet)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            Button {
                showAddAlarm = true
            } label: {
                Label(L10n.add, systemImage: "plus")
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Main List

    private var alarmListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(store.items.count) \(L10n.count)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showAddAlarm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if showAddAlarm {
                addAlarmForm
            }

            ForEach(store.sortedItems) { item in
                alarmRow(item)
            }
        }
    }

    // MARK: - Add Alarm Form

    private var addAlarmForm: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TextField(L10n.alarmLabel, text: $newLabel)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textPrimary)

            // 时间选择
            HStack(spacing: Theme.Spacing.sm) {
                Text(L10n.eventDate)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Picker("", selection: $newHour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 60)
                Text(":")
                    .foregroundColor(.textPrimary)
                Picker("", selection: $newMinute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 60)
            }

            // 重复日选择
            HStack(spacing: 4) {
                Text(L10n.alarmRepeat)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                ForEach(Weekday.allCases) { day in
                    Button {
                        if newRepeatDays.contains(day) {
                            newRepeatDays.remove(day)
                        } else {
                            newRepeatDays.insert(day)
                        }
                    } label: {
                        Text(day.shortLabel)
                            .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                            .foregroundColor(newRepeatDays.contains(day) ? .white : .textTertiary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(newRepeatDays.contains(day) ? Color.appAccent : Color.fillSubtle))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button(L10n.cancel) {
                    showAddAlarm = false
                    newLabel = ""
                    newRepeatDays = []
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button(L10n.add) {
                    let label = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.addAlarm(
                        label: label.isEmpty ? "闹钟" : label,
                        hour: newHour,
                        minute: newMinute,
                        repeatDays: newRepeatDays
                    )
                    showAddAlarm = false
                    newLabel = ""
                    newRepeatDays = []
                }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fillSubtle))
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Alarm Row

    private func alarmRow(_ item: AlarmItem) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // 时间
            Text(item.timeString)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(item.enabled ? .textPrimary : .textQuaternary)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(item.enabled ? .textPrimary : .textQuaternary)
                    .lineLimit(1)

                if item.isOneTime {
                    Text("单次")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textQuaternary)
                } else {
                    HStack(spacing: 2) {
                        ForEach(Weekday.allCases) { day in
                            Text(day.shortLabel)
                                .font(.system(size: 8))
                                .foregroundColor(item.repeatDays.contains(day) ? Color.appAccent : .textQuaternary)
                        }
                    }
                }
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { item.enabled },
                set: { _ in store.toggleAlarm(id: item.id) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            // 删除
            Button { store.deleteAlarm(id: item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textQuaternary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .background(Circle().fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }
}
