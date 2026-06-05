//
//  NotificationCenterView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/5.
//

import SwiftUI

// MARK: - Notification Center View

/// 通知中心视图 — 显示通知历史 + 免打扰设置
struct NotificationCenterView: View {
    @ObservedObject private var store = NotificationCenterStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedFilter: NotificationSource?
    @State private var showClearConfirm = false

    private var filteredRecords: [NotificationRecord] {
        if let filter = selectedFilter {
            return store.records(for: filter)
        }
        return store.records
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 标题栏
            headerBar

            // 免打扰设置
            dndSection

            // 过滤器
            filterBar

            // 通知列表
            if filteredRecords.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .onAppear {
            store.markAllRead()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("通知中心")
                    .font(.system(size: Theme.FontSize.headline, weight: .bold))
                    .foregroundColor(.textPrimary)

                Text("\(store.records.count) 条通知")
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            if !store.records.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Text("清空")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .alert("确认清空", isPresented: $showClearConfirm) {
                    Button("取消", role: .cancel) {}
                    Button("清空", role: .destructive) {
                        store.clearAll()
                    }
                } message: {
                    Text("确定要清空所有通知记录吗？")
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }

    // MARK: - DND Section

    private var dndSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Text("免打扰")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textSecondary)
                Spacer()
                Toggle("", isOn: $settings.dndEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            if settings.dndEnabled {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("时段")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)

                    Picker("", selection: $settings.dndStartHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    Text("至")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)

                    Picker("", selection: $settings.dndEndHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    Spacer()

                    if settings.isDNDActive {
                        Text("生效中")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        .padding(.horizontal, Theme.Spacing.sm)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                filterChip(nil, label: "全部")
                ForEach([NotificationSource.timer, .clipboard, .music, .system], id: \.self) { source in
                    filterChip(source, label: source.displayName)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    private func filterChip(_ source: NotificationSource?, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedFilter = source
            }
        } label: {
            HStack(spacing: 4) {
                if let source = source {
                    Image(systemName: source.systemImage)
                        .font(.system(size: 9))
                }
                Text(label)
                    .font(.system(size: Theme.FontSize.caption2))
            }
            .foregroundColor(selectedFilter == source ? .white : .textSecondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                Capsule()
                    .fill(selectedFilter == source ? Color.appAccent : Color.fillSubtle)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notification List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.xs) {
                ForEach(filteredRecords) { record in
                    NotificationRecordRow(record: record) {
                        store.removeRecord(record)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24))
                .foregroundColor(.textQuaternary)
            Text("暂无通知")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }
}

// MARK: - Notification Record Row

private struct NotificationRecordRow: View {
    let record: NotificationRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 来源图标
            Image(systemName: record.source.systemImage)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.fillSubtle))

            // 内容
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(record.body)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            // 时间 + 删除
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString)
                    .font(.system(size: Theme.FontSize.caption2, design: .monospaced))
                    .foregroundColor(.textQuaternary)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.textQuaternary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    private var timeString: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(record.timestamp) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(record.timestamp) {
            return "昨天"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: record.timestamp)
    }
}
