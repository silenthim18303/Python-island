//
//  PhonePairingView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

/// 设备配对设置页面
struct PhonePairingView: View {
    @ObservedObject var deviceService: PhoneServiceImpl
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 连接状态卡片
            PhoneStatusCard(deviceService: deviceService)

            // 操作按钮
            VStack(spacing: Theme.Spacing.sm) {
                switch deviceService.connectionState {
                case .idle, .disconnected, .error:
                    startButton
                case .advertising, .connecting:
                    stopButton
                case .connected:
                    disconnectButton
                }
            }

            // 使用说明
            instructionsSection

            // 支持的设备
            supportedDevicesSection

            // 设置选项
            settingsSection
        }
    }

    // MARK: - Action Buttons

    private var startButton: some View {
        Button {
            deviceService.startListening()
        } label: {
            Label(L10n.deviceStartPairing, systemImage: "antenna.radiowaves.left.and.right")
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.appAccent))
        }
        .buttonStyle(.plain)
    }

    private var stopButton: some View {
        Button {
            deviceService.stopListening()
        } label: {
            Label(L10n.deviceStopPairing, systemImage: "stop.circle")
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var disconnectButton: some View {
        Button {
            deviceService.disconnect()
        } label: {
            Label(L10n.deviceDisconnect, systemImage: "device.phone.portrait.badge.xmark")
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().stroke(.red.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("使用说明")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                instructionRow(number: "1", text: "确保设备和 Mac 连接到同一 WiFi 网络")
                instructionRow(number: "2", text: "点击「开始配对」按钮")
                instructionRow(number: "3", text: "在设备上打开 MacIsland 配套 App")
                instructionRow(number: "4", text: "App 会自动发现并连接到 Mac")
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.appAccent))
            Text(text)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Supported Devices

    private var supportedDevicesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("支持的设备")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                .foregroundColor(.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                DeviceBadge(icon: "iphone", name: "iPhone")
                DeviceBadge(icon: "ipad", name: "iPad")
                DeviceBadge(icon: "smartphone", name: "Android")
                DeviceBadge(icon: "smartphone", name: "鸿蒙")
                DeviceBadge(icon: "laptopcomputer", name: "Mac")
                DeviceBadge(icon: "pc", name: "Windows")
            }
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Toggle(isOn: $settings.phoneAutoStart) {
                Label("开机自动启动配对", systemImage: "power")
                    .font(.system(size: Theme.FontSize.caption))
            }
            .toggleStyle(.switch)
        }
        .padding(Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
    }
}

// MARK: - Device Badge

private struct DeviceBadge: View {
    let icon: String
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
    }
}
