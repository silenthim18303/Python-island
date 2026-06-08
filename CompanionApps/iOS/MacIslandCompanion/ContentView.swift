//
//  ContentView.swift
//  MacIslandCompanion
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showTestNotification = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 连接状态卡片
                connectionStatusCard

                // 连接按钮
                connectionButton

                // 测试功能
                if connectionManager.isConnected {
                    testSection
                }

                Spacer()
            }
            .padding()
            .navigationTitle("MacIsland")
            .alert("测试通知已发送", isPresented: $showTestNotification) {
                Button("确定", role: .cancel) {}
            }
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            // 状态图标
            Image(systemName: connectionManager.isConnected ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(connectionManager.isConnected ? .green : .blue)

            // 状态文本
            Text(connectionManager.connectionStatus)
                .font(.headline)
                .foregroundColor(.primary)

            // Mac 名称
            if connectionManager.isConnected {
                Text("已连接到 \(connectionManager.macName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 错误信息
            if let error = connectionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Connection Button

    private var connectionButton: some View {
        Button(action: {
            if connectionManager.isConnected {
                connectionManager.disconnect()
            } else {
                connectionManager.startSearching()
            }
        }) {
            HStack {
                Image(systemName: connectionManager.isConnected ? "xmark.circle" : "magnifyingglass")
                Text(connectionManager.isConnected ? "断开连接" : "搜索 MacIsland")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(connectionManager.isConnected ? Color.red : Color.blue)
            .cornerRadius(12)
        }
        .disabled(connectionManager.isSearching)
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(spacing: 12) {
            Text("测试功能")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 发送测试通知
            Button(action: {
                connectionManager.sendNotification(
                    title: "测试通知",
                    body: "这是一条来自 iPhone 的测试通知",
                    appName: "MacIsland Companion"
                )
                showTestNotification = true
            }) {
                HStack {
                    Image(systemName: "bell.fill")
                    Text("发送测试通知")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(12)
            }

            // 连接信息
            VStack(alignment: .leading, spacing: 8) {
                Text("连接信息")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack {
                    Text("设备名称")
                    Spacer()
                    Text(UIDevice.current.name)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("系统版本")
                    Spacer()
                    Text("iOS \(UIDevice.current.systemVersion)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("连接状态")
                    Spacer()
                    Text(connectionManager.isConnected ? "已连接" : "未连接")
                        .foregroundColor(connectionManager.isConnected ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ConnectionManager())
}
