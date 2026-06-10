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
    @ObservedObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra("MacIsland", systemImage: "circle.fill") {
            MenuBarView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
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
                .environmentObject(AppSettings.shared)
                .environmentObject(LocalizationManager.shared)
                .environmentObject(serviceContainer.weather)
                .environmentObject(serviceContainer.music)
                .environmentObject(serviceContainer.monitor)
                .environmentObject(serviceContainer.lyrics)
                .environmentObject(serviceContainer.timer)
                .environmentObject(serviceContainer.clipboard)
                .environmentObject(serviceContainer.hotkey)
                .environmentObject(serviceContainer.voice)
                .environmentObject(serviceContainer.stocks)
                .environmentObject(StockStore.shared)
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
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    @State private var isVisible = true

    var body: some View {
        VStack(spacing: 4) {
            // 标题
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color.appAccent)

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

                    Text(isVisible ? L10n.menuHideIsland : L10n.menuShowIsland)

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

                    Text(L10n.menuCollapse)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // 检查更新
            Button {
                Task {
                    await updateManager.checkForUpdates()
                }
            } label: {
                HStack {
                    Image(systemName: updateManager.isChecking ? "arrow.triangle.2.circlepath.circle" : "arrow.triangle.2.circlepath")
                        .frame(width: 16)
                        .rotationEffect(.degrees(updateManager.isChecking ? 360 : 0))
                        .animation(updateManager.isChecking ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: updateManager.isChecking)

                    Text(L10n.menuCheckForUpdates)

                    Spacer()

                    // 显示更新状态
                    if case .available(let version, _, _) = updateManager.status {
                        Text("v\(version)")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // 设置（打开灵动岛设置标签）
            Button {
                IslandWindowManager.shared.show()
                // 通过通知让 IslandStore 切到 MaxExpand + 设置标签
                NotificationCenter.default.post(name: .openIslandSettings, object: nil)
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                        .frame(width: 16)

                    Text(L10n.menuSettings)

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

                    Text(L10n.menuQuit)

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .onChange(of: updateManager.status) { _, newStatus in
            handleUpdateStatus(newStatus)
        }
    }

    /// 处理更新状态变化
    private func handleUpdateStatus(_ status: UpdateStatus) {
        switch status {
        case .available(let version, let downloadUrl, let releaseNotes):
            showUpdateAlert(version: version, downloadUrl: downloadUrl, releaseNotes: releaseNotes)
        case .upToDate:
            showUpToDateAlert()
        case .error(let message):
            showErrorAlert(message: message)
        default:
            break
        }
    }

    /// 显示更新提示
    private func showUpdateAlert(version: String, downloadUrl: String, releaseNotes: String?) {
        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle
        alert.informativeText = L10n.updateAvailableMessage(version: version)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.updateDownload)
        alert.addButton(withTitle: L10n.updateLater)

        if let notes = releaseNotes, !notes.isEmpty {
            alert.accessoryView = createReleaseNotesView(notes)
        }

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task {
                await updateManager.downloadAndInstall(url: downloadUrl)
            }
        }
    }

    /// 显示已是最新版本
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.updateUpToDateTitle
        alert.informativeText = L10n.updateUpToDateMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// 显示错误提示
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.updateErrorTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// 创建更新日志视图
    private func createReleaseNotesView(_ notes: String) -> NSView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.string = notes
        textView.isEditable = false
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = NSColor.secondaryLabelColor

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.frame = NSRect(x: 0, y: 0, width: 300, height: 100)

        return scrollView
    }
}
