//
//  PhoneSettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

/// 设备配对设置页面（用于原生设置窗口）
struct PhoneSettingsView: View {
    @EnvironmentObject var deviceService: PhoneServiceImpl

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 连接状态卡片
                PhoneStatusCard(deviceService: deviceService)

                // 操作按钮
                VStack(spacing: 12) {
                    switch deviceService.connectionState {
                    case .idle, .disconnected, .error:
                        Button {
                            deviceService.startListening()
                        } label: {
                            Label(L10n.deviceStartPairing, systemImage: "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                    case .advertising, .connecting:
                        Button {
                            deviceService.stopListening()
                        } label: {
                            Label(L10n.deviceStopPairing, systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                    case .connected:
                        Button {
                            deviceService.disconnect()
                        } label: {
                            Label(L10n.deviceDisconnect, systemImage: "device.phone.portrait.badge.xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                // 使用说明
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用说明")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        instructionRow(number: "1", text: "确保设备和 Mac 连接到同一 WiFi 网络")
                        instructionRow(number: "2", text: "点击「开始配对」按钮")
                        instructionRow(number: "3", text: "在设备上打开 MacIsland 配套 App")
                        instructionRow(number: "4", text: "App 会自动发现并连接到 Mac")
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

                // 支持的设备
                VStack(alignment: .leading, spacing: 12) {
                    Text("支持的设备")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 12) {
                        SupportedDeviceCard(icon: "iphone", name: "iPhone", description: "iOS 15+")
                        SupportedDeviceCard(icon: "ipad", name: "iPad", description: "iPadOS 15+")
                        SupportedDeviceCard(icon: "smartphone", name: "Android", description: "Android 10+")
                        SupportedDeviceCard(icon: "laptopcomputer", name: "Mac", description: "macOS 13+")
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

                // 协议信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("协议信息")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("服务类型: _macisland._tcp")
                            .font(.system(.body, design: .monospaced))
                        Text("传输协议: TCP (Bonjour)")
                            .font(.system(.body, design: .monospaced))
                        Text("消息格式: JSON + Length-Prefix")
                            .font(.system(.body, design: .monospaced))
                        Text("发现方式: mDNS / Peer-to-Peer")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            }
            .padding()
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.blue))
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Supported Device Card

private struct SupportedDeviceCard: View {
    let icon: String
    let name: String
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.accentColor)

            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}
