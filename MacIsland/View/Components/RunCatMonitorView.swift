//
//  RunCatMonitorView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - RunCat Monitor View

/// 紧凑系统监控视图 — 2列网格 + 全宽网络
struct RunCatMonitorView: View {
    let stats: SystemStats
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // 2列网格：CPU + 内存
            HStack(spacing: Theme.Spacing.xs) {
                compactCard(
                    icon: "cpu", color: .blue,
                    title: "CPU", value: String(format: "%.1f%%", stats.cpuUsage),
                    rows: [
                        ("系统", String(format: "%.1f%%", stats.cpuSystem)),
                        ("用户", String(format: "%.1f%%", stats.cpuUser)),
                    ],
                    percent: stats.cpuUsage / 100, barColor: .blue
                )
                compactCard(
                    icon: "memorychip", color: .purple,
                    title: "内存", value: String(format: "%.1f%%", stats.memoryPercent),
                    rows: [
                        ("App", String(format: "%.1fG", stats.memoryApp)),
                        ("压缩", String(format: "%.1fG", stats.memoryCompressed)),
                    ],
                    percent: stats.memoryPercent / 100, barColor: .purple
                )
            }

            // 2列网格：储存 + 电池
            HStack(spacing: Theme.Spacing.xs) {
                compactCard(
                    icon: "internaldrive", color: .green,
                    title: "储存", value: String(format: "%.1f%%", stats.diskPercent),
                    rows: [
                        ("已用", String(format: "%.0fG", stats.diskUsed)),
                        ("空闲", String(format: "%.0fG", stats.diskTotal - stats.diskUsed)),
                    ],
                    percent: stats.diskPercent / 100, barColor: .green
                )
                compactCard(
                    icon: batteryIcon, color: batteryColor,
                    title: "电池", value: String(format: "%.0f%%", stats.batteryLevel),
                    rows: [
                        ("容量", String(format: "%.0f%%", stats.batteryMaxCapacity)),
                        ("循环", "\(stats.batteryCycleCount)"),
                    ],
                    percent: stats.batteryLevel / 100, barColor: batteryColor
                )
            }

            // 全宽网络
            networkRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { animateProgress = true } }
    }

    // MARK: - Compact Card

    private func compactCard(
        icon: String, color: Color,
        title: String, value: String,
        rows: [(String, String)],
        percent: Double, barColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 标题行
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            // 详情行
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    if !row.0.isEmpty {
                        Text(row.0)
                            .font(.system(size: 9))
                            .foregroundColor(.textQuaternary)
                        Spacer()
                    }
                    Text(row.1)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor.opacity(0.6))
                        .frame(width: animateProgress ? geo.size.width * min(percent, 1.0) : 0)
                        .animation(.easeOut(duration: 0.6), value: animateProgress)
                }
            }
            .frame(height: 3)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.fillSubtle))
    }

    // MARK: - Network Row

    private var networkRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: stats.networkConnected ? "globe" : "globe.badge.xmark")
                .font(.system(size: 12))
                .foregroundColor(stats.networkConnected ? .cyan : .red)
                .frame(width: 16)

            Text("网络")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textPrimary)

            if stats.networkConnected {
                Text(stats.networkType.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.cyan.opacity(0.15)))
            }

            Spacer()

            if !stats.localIP.isEmpty {
                Text(stats.localIP)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.textQuaternary)
            }

            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 7))
                    Text(formatSpeed(stats.uploadSpeed))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.textTertiary)

                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 7))
                    Text(formatSpeed(stats.downloadSpeed))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.fillSubtle))
    }

    // MARK: - Helpers

    private var batteryIcon: String {
        if stats.batteryIsCharging { return "battery.100.bolt" }
        if stats.batteryLevel > 75 { return "battery.100" }
        if stats.batteryLevel > 50 { return "battery.75" }
        if stats.batteryLevel > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        if stats.batteryIsCharging { return .green }
        if stats.batteryLevel > 50 { return .green }
        if stats.batteryLevel > 20 { return .yellow }
        return .red
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return String(format: "%.0fB", bytesPerSec) }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.1fK", bytesPerSec / 1024) }
        return String(format: "%.1fM", bytesPerSec / 1024 / 1024)
    }
}
