//
//  HotkeyService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import AppKit
import ApplicationServices
import Combine

/// 全局快捷键服务 — 使用 NSEvent 全局监听
final class HotkeyService: HotkeyServiceProtocol, ObservableObject {
    private var monitor: Any?
    private var lastFireTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.3
    private var permissionTimer: Timer?

    // Callbacks injected by ServiceContainer
    var onToggleIsland: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    // MARK: - Permission Status

    /// 当前进程是否已获得辅助功能权限（实时轮询更新，供 SwiftUI 视图响应式订阅）
    @Published var isAccessibilityGranted: Bool = AXIsProcessTrusted()

    /// 打开「系统设置 → 隐私与安全性 → 辅助功能」，引导用户手动授予权限
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Permission Polling

    /// 启动权限轮询（每 2 秒检查一次，授权后自动启动快捷键监听并停止轮询）
    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let granted = AXIsProcessTrusted()
            if granted != self.isAccessibilityGranted {
                self.isAccessibilityGranted = granted
            }
            if granted {
                self.stopPermissionPolling()
                self.startMonitoringInternal()
            }
        }
    }

    private func stopPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard monitor == nil else { return }

        // 同步一次权限状态
        isAccessibilityGranted = AXIsProcessTrusted()

        guard isAccessibilityGranted else {
            // 权限不足：主动弹出系统授权弹窗（macOS 会提示用户在设置中添加应用）
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            // 启动轮询，等待用户在系统设置中授权
            startPermissionPolling()
            print("[Hotkey] 未授予辅助功能权限，快捷键不可用。请在「系统设置 → 隐私与安全性 → 辅助功能」中授权。")
            return
        }

        startMonitoringInternal()
    }

    /// 实际注册全局键盘监听（权限已确认可用时调用）
    private func startMonitoringInternal() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        print("[Hotkey] 全局快捷键监听已启动")
    }

    func stopMonitoring() {
        stopPermissionPolling()
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // MARK: - Key Handling

    private func handleKeyEvent(_ event: NSEvent) {
        let now = Date()
        guard now.timeIntervalSince(lastFireTime) >= debounceInterval else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        let keyCode = event.keyCode

        // 遍历用户配置的快捷键绑定，匹配 modifiers + keyCode
        let bindings = AppSettings.shared.hotkeyBindings
        for (action, combo) in bindings {
            if combo.keyCode == keyCode && combo.modifiers == flags {
                lastFireTime = now
                DispatchQueue.main.async { self.triggerAction(action) }
                return
            }
        }
    }

    /// HotkeyAction → 回调映射
    private func triggerAction(_ action: HotkeyAction) {
        switch action {
        case .toggleIsland:  onToggleIsland?()
        case .playPause:     onPlayPause?()
        case .nextTrack:     onNextTrack?()
        case .previousTrack: onPreviousTrack?()
        }
    }
}
