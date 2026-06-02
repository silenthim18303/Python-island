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

    // Callbacks injected by ServiceContainer
    var onToggleIsland: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    // MARK: - Monitoring

    func startMonitoring() {
        guard monitor == nil else { return }
        // 全局键盘监听需要辅助功能权限，否则静默失效——触发系统授权弹窗
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            print("[Hotkey] 未授予辅助功能权限，快捷键不可用")
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    func stopMonitoring() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    // MARK: - Key Handling

    private func handleKeyEvent(_ event: NSEvent) {
        // Debounce
        let now = Date()
        guard now.timeIntervalSince(lastFireTime) >= debounceInterval else { return }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        // ⌥⌘ + key
        guard flags.contains([.option, .command]) else { return }

        switch keyCode {
        case 0x22: // I
            lastFireTime = now
            DispatchQueue.main.async { self.onToggleIsland?() }
        case 0x23: // P
            lastFireTime = now
            DispatchQueue.main.async { self.onPlayPause?() }
        case 0x7C: // Right Arrow
            lastFireTime = now
            DispatchQueue.main.async { self.onNextTrack?() }
        case 0x7B: // Left Arrow
            lastFireTime = now
            DispatchQueue.main.async { self.onPreviousTrack?() }
        default:
            break
        }
    }
}
