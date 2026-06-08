//
//  LaunchAtLoginManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation
import ServiceManagement
import Combine

/// 开机自启管理器
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false
    @Published var error: String?

    private init() {
        refreshStatus()
    }

    // MARK: - Public Methods

    /// 刷新当前状态
    func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    /// 设置开机自启
    func setEnabled(_ enabled: Bool) {
        error = nil

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    isEnabled = true
                    print("[LaunchAtLogin] 已启用开机自启")
                } else {
                    try SMAppService.mainApp.unregister()
                    isEnabled = false
                    print("[LaunchAtLogin] 已禁用开机自启")
                }
            } catch {
                self.error = error.localizedDescription
                isEnabled = SMAppService.mainApp.status == .enabled
                print("[LaunchAtLogin] 设置失败: \(error)")
            }
        } else {
            // macOS 12 及更早版本使用旧 API
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            if enabled {
                if !SMLoginItemSetEnabled(bundleIdentifier as CFString, true) {
                    self.error = "无法启用开机自启"
                } else {
                    isEnabled = true
                }
            } else {
                if !SMLoginItemSetEnabled(bundleIdentifier as CFString, false) {
                    self.error = "无法禁用开机自启"
                } else {
                    isEnabled = false
                }
            }
        }
    }

    /// 切换开机自启状态
    func toggle() {
        setEnabled(!isEnabled)
    }
}
