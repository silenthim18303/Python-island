//
//  MacIslandApp.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - App Entry Point

@main
struct MacIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MacIsland", systemImage: "circle.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: ServiceContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标（灵动岛是后台浮动应用）
        NSApp.setActivationPolicy(.accessory)

        // 提前初始化共享设置（动画/功能开关等偏好），供窗口与视图读取
        _ = AppSettings.shared

        // 初始化服务容器
        let serviceContainer = ServiceContainer()
        self.services = serviceContainer

        // 创建灵动岛窗口
        IslandWindowManager.shared.createWindow(
            content: ContentView()
                .environmentObject(serviceContainer.weather)
                .environmentObject(serviceContainer.music)
                .environmentObject(serviceContainer.monitor)
                .environmentObject(serviceContainer.lyrics)
                .environmentObject(serviceContainer.timer)
                .environmentObject(serviceContainer.clipboard)
                .environmentObject(serviceContainer.hotkey)
        )

        // 启动所有数据服务
        serviceContainer.startAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        services?.stopAll()
        IslandWindowManager.shared.destroy()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 不因窗口关闭而退出（菜单栏常驻）
        return false
    }
}

// MARK: - Menu Bar View

/// 菜单栏控制视图
struct MenuBarView: View {
    @State private var isVisible = true

    var body: some View {
        VStack(spacing: 4) {
            // 标题
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.accentColor)

                Text("MacIsland")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // 显隐切换
            Button {
                IslandWindowManager.shared.toggle()
                isVisible.toggle()
            } label: {
                HStack {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .frame(width: 16)

                    Text(isVisible ? "隐藏灵动岛" : "显示灵动岛")

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // 折叠岛（回到 idle 态）
            Button {
                IslandWindowManager.shared.collapse()
            } label: {
                HStack {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .frame(width: 16)

                    Text("折叠岛")

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // 设置
            SettingsLink {
                HStack {
                    Image(systemName: "gearshape")
                        .frame(width: 16)

                    Text("设置…")

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            // 退出
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .frame(width: 16)

                    Text("退出 MacIsland")

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
    }
}
