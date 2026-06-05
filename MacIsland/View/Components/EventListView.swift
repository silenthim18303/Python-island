//
//  EventListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Event List View

/// 倒数日列表视图
struct EventListView: View {
    @ObservedObject var store: EventStore

    @State private var showAddEvent = false
    @State private var newTitle = ""
    @State private var newType: EventType = .countdown
    @State private var newDate = Date()

    var body: some View {
        if store.sortedItems.isEmpty && !showAddEvent {
            onboardingView
        } else {
            eventListView
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text(L10n.eventTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(L10n.eventTrack)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showAddEvent = true
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

    private var eventListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(store.items.count) \(L10n.count)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if showAddEvent {
                addEventForm
            }

            ForEach(store.sortedItems) { item in
                eventRow(item)
            }
        }
    }

    // MARK: - Add Event Form

    private var addEventForm: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TextField(L10n.eventName, text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textPrimary)

            HStack(spacing: Theme.Spacing.sm) {
                Picker(L10n.eventTitle, selection: $newType) {
                    ForEach(EventType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)

                DatePicker(L10n.eventDate, selection: $newDate, displayedComponents: .date)
                    .labelsHidden()
            }

            HStack {
                Button(L10n.cancel) {
                    showAddEvent = false
                    newTitle = ""
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button(L10n.add) {
                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    store.addEvent(title: title, type: newType, targetDate: newDate)
                    showAddEvent = false
                    newTitle = ""
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

    // MARK: - Event Row

    private func eventRow(_ item: EventItem) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // 天数显示
            VStack(spacing: 2) {
                Text("\(abs(item.daysRemaining))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(item.isPast ? .textQuaternary : daysColor(item.daysRemaining))
                Text(item.isPast ? "天前" : "天")
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textQuaternary)
            }
            .frame(width: 50)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(item.enabled ? .textPrimary : .textQuaternary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.eventType.rawValue)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(eventTypeColor(item.eventType))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(eventTypeColor(item.eventType).opacity(0.15)))

                    Text(item.targetDate, style: .date)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textQuaternary)
                }
            }

            Spacer()

            // 操作
            Button { store.deleteEvent(id: item.id) } label: {
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

    // MARK: - Helpers

    private func daysColor(_ days: Int) -> Color {
        if days <= 1 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .green
    }

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .countdown: return .blue
        case .anniversary: return .pink
        case .birthday: return .purple
        case .holiday: return .green
        case .exam: return .orange
        }
    }
}
