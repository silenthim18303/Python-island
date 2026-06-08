//
//  PhoneStatusView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

/// 设备状态紧凑视图 - 用于展开态概览
struct PhoneStatusView: View {
    @ObservedObject var deviceService: PhoneServiceImpl

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 设备图标 + 连接状态指示
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: deviceIcon)
                    .font(.system(size: 18))
                    .foregroundColor(connectionColor)

                Circle()
                    .fill(connectionDotColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.fillSubtle, lineWidth: 1.5))
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(deviceService.connectedDevice?.displayName ?? L10n.deviceNotConnected)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                if let battery = deviceService.deviceBattery {
                    HStack(spacing: 4) {
                        Image(systemName: battery.batteryIcon)
                            .font(.system(size: 9))
                        Text(battery.percentString)
                            .font(.system(size: Theme.FontSize.caption2, design: .monospaced))
                    }
                    .foregroundColor(batteryColor(battery))
                } else {
                    Text(deviceService.connectionState.displayName)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            // 断开按钮（仅连接时显示）
            if deviceService.connectionState == .connected {
                Button {
                    deviceService.disconnect()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textQuaternary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Helpers

    private var deviceIcon: String {
        if let device = deviceService.connectedDevice {
            return device.deviceType.systemImage
        }
        return deviceService.connectionState.systemImage
    }

    private var connectionColor: Color {
        switch deviceService.connectionState {
        case .connected: return .green
        case .advertising: return .orange
        case .connecting: return .blue
        case .error: return .red
        default: return .secondary
        }
    }

    private var connectionDotColor: Color {
        switch deviceService.connectionState {
        case .connected: return .green
        case .advertising: return .orange
        case .connecting: return .blue
        case .error: return .red
        default: return .gray
        }
    }

    private func batteryColor(_ battery: DeviceBatteryStatus) -> Color {
        if battery.isCharging { return .green }
        if battery.level <= 0.20 { return .red }
        if battery.level <= 0.50 { return .orange }
        return .primary
    }
}

/// 设备状态卡片 - 用于设置页面
struct PhoneStatusCard: View {
    @ObservedObject var deviceService: PhoneServiceImpl

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 连接状态
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: statusIcon)
                    .font(.system(size: 24))
                    .foregroundColor(statusColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(statusColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(statusDescription)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)
                }
                Spacer()
            }

            // 连接方式
            if deviceService.connectionState == .connected {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: deviceService.connectionType.systemImage)
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                    Text("连接方式")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text(deviceService.connectionType.displayName)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.textPrimary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)))
            }

            // 设备信息
            if let device = deviceService.connectedDevice {
                Divider()
                deviceInfoRow(icon: device.deviceType.systemImage, title: "设备", value: device.name)
                deviceInfoRow(icon: "gear", title: "型号", value: device.model)
                deviceInfoRow(icon: "info.circle", title: "系统", value: "\(device.deviceType.displayName) \(device.systemVersion)")
            }

            // 电池信息
            if let battery = deviceService.deviceBattery {
                Divider()
                HStack {
                    Image(systemName: battery.batteryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(batteryColor(battery))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("电池")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textSecondary)
                        Text(battery.percentString)
                            .font(.system(size: Theme.FontSize.body, weight: .bold, design: .monospaced))
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                    if battery.isCharging {
                        Label("充电中", systemImage: "bolt.fill")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.green)
                    }
                    if battery.isLowPowerMode {
                        Label("低电量", systemImage: "battery.25")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
    }

    // MARK: - Helpers

    private var statusIcon: String {
        if let device = deviceService.connectedDevice {
            return device.deviceType.systemImage
        }
        return deviceService.connectionState.systemImage
    }

    private var statusTitle: String {
        if let device = deviceService.connectedDevice {
            return device.displayName
        }
        return deviceService.connectionState.displayName
    }

    private var statusDescription: String {
        switch deviceService.connectionState {
        case .idle: return "点击下方按钮开始配对"
        case .advertising: return "等待设备连接..."
        case .connecting: return "正在建立连接..."
        case .connected:
            if let device = deviceService.connectedDevice {
                return "\(device.deviceType.displayName) 已连接"
            }
            return "设备已连接"
        case .disconnected: return "连接已断开"
        case .error: return "连接出错，请重试"
        }
    }

    private var statusColor: Color {
        switch deviceService.connectionState {
        case .connected: return .green
        case .advertising: return .orange
        case .connecting: return .blue
        case .error: return .red
        default: return .secondary
        }
    }

    private func batteryColor(_ battery: DeviceBatteryStatus) -> Color {
        if battery.isCharging { return .green }
        if battery.level <= 0.20 { return .red }
        if battery.level <= 0.50 { return .orange }
        return .primary
    }

    private func deviceInfoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.textQuaternary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.textPrimary)
        }
    }
}
