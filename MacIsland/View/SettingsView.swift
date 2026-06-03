//
//  SettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI
import ApplicationServices
import Combine
import ServiceManagement

// MARK: - Settings View

/// 原生偏好设置窗口
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }

            ShortcutsSettingsView()
                .tabItem { Label("快捷键", systemImage: "command") }

            AboutSettingsView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 360)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newDomain: String = ""

    var body: some View {
        Form {
            Section("外观") {
                LanguageSettingsView()

                Toggle("开机自启动", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                HStack {
                    Text("灵动岛透明度")
                    Spacer()
                    Text("\(Int(settings.islandOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.islandOpacity, in: 0.1...1.0, step: 0.05)
            }

            Section("动画") {
                Picker("动画速度", selection: $settings.animationSpeed) {
                    ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("弹簧动画", isOn: $settings.springAnimation)
            }

            Section("剪贴板") {
                Toggle("链接检测", isOn: $settings.clipboardEnabled)

                Picker("URL 检测模式", selection: $settings.clipboardUrlDetectMode) {
                    Text("仅 HTTPS").tag(ClipboardUrlDetectMode.httpsOnly)
                    Text("HTTP + HTTPS").tag(ClipboardUrlDetectMode.httpHttps)
                    Text("仅域名").tag(ClipboardUrlDetectMode.domainOnly)
                }

                // 域名黑名单
                VStack(alignment: .leading, spacing: 6) {
                    Text("域名黑名单")
                        .font(.headline)

                    if settings.blacklistedDomains.isEmpty {
                        Text("暂无黑名单域名")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(settings.blacklistedDomains.sorted()), id: \.self) { domain in
                            HStack {
                                Text(domain)
                                    .font(.callout)
                                Spacer()
                                Button {
                                    settings.blacklistedDomains.remove(domain)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("输入域名，如 example.com", text: $newDomain)
                            .textFieldStyle(.roundedBorder)
                        Button("添加") {
                            let domain = newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
                                .lowercased()
                                .replacingOccurrences(of: "https://", with: "")
                                .replacingOccurrences(of: "http://", with: "")
                                .replacingOccurrences(of: "/", with: "")
                            if !domain.isEmpty {
                                settings.blacklistedDomains.insert(domain)
                                newDomain = ""
                            }
                        }
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login Item 设置失败: \(error)")
            }
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var recordingAction: HotkeyAction?
    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            // 权限状态
            Section {
                if !accessibilityGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("辅助功能权限未授予，快捷键不可用")
                                .font(.callout)
                            Text("点击下方按钮，在系统设置中为 MacIsland 打勾授权")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("打开系统设置") {
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            NSWorkspace.shared.open(url)
                        }
                        .controlSize(.small)
                    }
                    .padding(6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("辅助功能权限已授予，快捷键可用")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 快捷键绑定
            Section("全局快捷键") {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    HotkeyRow(
                        action: action,
                        binding: settings.hotkeyBindings[action] ?? KeyCombo.defaultBindings[action]!,
                        isRecording: recordingAction == action
                    ) { combo in
                        // 冲突检测：如果新 combo 已被另一个 action 使用，交换两者
                        if let conflict = settings.hotkeyBindings.first(where: { $0.key != action && $0.value == combo }) {
                            settings.hotkeyBindings[conflict.key] = settings.hotkeyBindings[action]
                        }
                        settings.hotkeyBindings[action] = combo
                        recordingAction = nil
                    } onStartRecording: {
                        recordingAction = action
                    }
                }

                // 恢复默认
                Button("恢复默认快捷键") {
                    settings.resetHotkeyBindings()
                    recordingAction = nil
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onReceive(pollTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }
}

// MARK: - Hotkey Row

/// 单行快捷键配置：功能名 + 快捷键录制器
private struct HotkeyRow: View {
    let action: HotkeyAction
    let binding: KeyCombo
    let isRecording: Bool
    let onCapture: (KeyCombo) -> Void
    let onStartRecording: () -> Void

    var body: some View {
        HStack {
            Text(action.displayName)
            Spacer()
            KeyRecorderView(
                isRecording: isRecording,
                displayString: binding.displayString,
                onCapture: onCapture,
                onStartRecording: onStartRecording
            )
        }
    }
}

// MARK: - Key Recorder View (NSViewRepresentable)

/// 快捷键录制器 — 点击进入录制模式，捕获下一个键盘组合
private struct KeyRecorderView: NSViewRepresentable {
    let isRecording: Bool
    let displayString: String
    let onCapture: (KeyCombo) -> Void
    let onStartRecording: () -> Void

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onCapture = onCapture
        view.onStartRecording = onStartRecording
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onCapture = onCapture
        nsView.displayString = displayString
        nsView.updateVisualState()
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

// MARK: - Key Recorder NSView

/// 实际捕获 keyDown 的 NSView
private class KeyRecorderNSView: NSView {
    var isRecording: Bool = false
    var displayString: String = ""
    var onCapture: ((KeyCombo) -> Void)?
    var onStartRecording: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLabel()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
    }

    private func setupLabel() {
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        wantsLayer = true
        layer?.cornerRadius = 4
        updateVisualState()
    }

    /// 更新视觉状态（录制中高亮 / 正常显示）
    func updateVisualState() {
        if isRecording {
            label.stringValue = "按下快捷键…"
            label.textColor = .controlAccentColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        } else {
            label.stringValue = displayString
            label.textColor = .labelColor
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }
    }

    // MARK: - First Responder & Hit Testing

    override var acceptsFirstResponder: Bool { true }

    /// 整个区域可点击（触发录制）
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            onStartRecording?()
        }
    }

    // MARK: - Key Capture

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 纯修饰键按下（如只按 ⌥）不算，等待完整组合
        let modifierOnlyKeyCodes: Set<UInt16> = [0x37, 0x38, 0x3A, 0x3B] // ⌘⇧⌥⌃
        if modifierOnlyKeyCodes.contains(event.keyCode) {
            return
        }

        // Escape 取消录制
        if event.keyCode == 0x35 {
            isRecording = false
            updateVisualState()
            return
        }

        // 至少需要一个修饰键（纯字母快捷键容易冲突）
        let nonModifierFlags = flags.subtracting([.function, .numericPad])
        guard !nonModifierFlags.isEmpty else {
            // 无修饰键，忽略
            NSSound.beep()
            return
        }

        let combo = KeyCombo(modifiers: flags.rawValue, keyCode: event.keyCode)
        onCapture?(combo)
    }

    /// 修饰键变化时实时更新显示（让用户看到按了哪些修饰键）
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts = ""
        if flags.contains(.control) { parts += "⌃" }
        if flags.contains(.option)  { parts += "⌥" }
        if flags.contains(.shift)   { parts += "⇧" }
        if flags.contains(.command) { parts += "⌘" }
        label.stringValue = parts.isEmpty ? "按下快捷键…" : parts
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("MacIsland")
                .font(.title2.bold())

            Text("版本 \(version)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
