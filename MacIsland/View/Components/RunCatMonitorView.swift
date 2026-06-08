//
//  RunCatMonitorView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - RunCat Monitor View

/// 紧凑系统监控视图 — 2×2 网络 + 全宽网络，所有卡片统一高度
struct RunCatMonitorView: View {
    @EnvironmentObject var monitor: SystemMonitorServiceImpl
    @State private var animateProgress = false

    private var stats: SystemStats { monitor.stats }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            // 2列网格：CPU + 内存
            HStack(spacing: Theme.Spacing.xs) {
                cpuCard
                memoryCard
            }

            // 2列网格：储存 + 电池
            HStack(spacing: Theme.Spacing.xs) {
                diskCard
                batteryCard
            }

            // 全宽网络
            networkCard
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { animateProgress = true } }
    }

    // MARK: - CPU Card（核心数/温度合入标题行）

    private var cpuCard: some View {
        unifiedCard(
            icon: "cpu", color: .blue,
            title: "CPU", value: String(format: "%.1f%%", stats.cpuUsage),
            subtitle: stats.cpuTemperature > 0
                ? "\(stats.cpuCoreCount) \(L10n.monitorCores) \(Int(stats.cpuTemperature))°C"
                : "\(stats.cpuCoreCount) \(L10n.monitorCores)",
            rows: [
                (L10n.monitorSystem, String(format: "%.1f%%", stats.cpuSystem)),
                (L10n.monitorUser, String(format: "%.1f%%", stats.cpuUser)),
            ],
            percent: stats.cpuUsage / 100, barColor: .blue
        )
    }

    // MARK: - Memory Card

    private var memoryCard: some View {
        unifiedCard(
            icon: "memorychip", color: .purple,
            title: L10n.monitorMemory, value: String(format: "%.1f%%", stats.memoryPercent),
            subtitle: String(format: "%.1fG / %.0fG", stats.memoryUsed, stats.memoryTotal),
            rows: [
                (L10n.monitorApp, String(format: "%.1fG", stats.memoryApp)),
                (L10n.monitorCompressed, String(format: "%.1fG", stats.memoryCompressed)),
            ],
            percent: stats.memoryPercent / 100, barColor: .purple
        )
    }

    // MARK: - Disk Card

    private var diskCard: some View {
        unifiedCard(
            icon: "internaldrive", color: .green,
            title: L10n.monitorDisk, value: String(format: "%.1f%%", stats.diskPercent),
            subtitle: String(format: "%.0fG / %.0fG", stats.diskUsed, stats.diskTotal),
            rows: [
                (L10n.monitorUsed, String(format: "%.0fG", stats.diskUsed)),
                (L10n.monitorIdle, String(format: "%.0fG", stats.diskTotal - stats.diskUsed)),
            ],
            percent: stats.diskPercent / 100, barColor: .green
        )
    }

    // MARK: - Battery Card

    private var batteryCard: some View {
        unifiedCard(
            icon: batteryIcon, color: batteryColor,
            title: L10n.monitorBattery, value: String(format: "%.0f%%", stats.batteryLevel),
            subtitle: stats.batteryIsCharging ? L10n.monitorCharging : L10n.monitorRemaining,
            rows: [
                (L10n.monitorCapacity, String(format: "%.0f%%", stats.batteryMaxCapacity)),
                (L10n.monitorCycles, "\(stats.batteryCycleCount) \(L10n.monitorCycles)"),
            ],
            percent: stats.batteryLevel / 100, barColor: batteryColor
        )
    }

    // MARK: - Unified Card（统一尺寸卡片）

    private func unifiedCard(
        icon: String, color: Color,
        title: String, value: String,
        subtitle: String,
        rows: [(String, String)],
        percent: Double, barColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题行：图标 + 标题 + 数值
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            // 副标题行（核心数/总量等）
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.textQuaternary)
                .padding(.top, 1)

            Spacer(minLength: 2)

            // 详情行 — 固定 2 行
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0)
                        .font(.system(size: 8))
                        .foregroundColor(.textQuaternary)
                    Spacer()
                    Text(row.1)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
            }

            Spacer(minLength: 2)

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
            .frame(height: 2)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(minHeight: 68)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.fillSubtle))
    }

    // MARK: - Network Card（与卡片风格统一）

    private var networkCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 左侧：图标 + 标题 + 类型
            HStack(spacing: 5) {
                Image(systemName: stats.networkConnected ? "globe" : "globe.badge.xmark")
                    .font(.system(size: 11))
                    .foregroundColor(stats.networkConnected ? .cyan : .red)

                Text(L10n.monitorNetwork)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textPrimary)

                if stats.networkConnected {
                    Text(stats.networkType.rawValue)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.cyan.opacity(0.15)))
                }
            }

            Spacer()

            // 中间：IP
            if !stats.localIP.isEmpty {
                Text(stats.localIP)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.textQuaternary)
            }

            // 右侧：上下行速度
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 6))
                    Text(formatSpeed(stats.uploadSpeed))
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.textTertiary)

                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 6))
                    Text(formatSpeed(stats.downloadSpeed))
                        .font(.system(size: 8, design: .monospaced))
                }
                .foregroundColor(.textTertiary)
            }
        }
        .padding(.horizontal, 7)
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
