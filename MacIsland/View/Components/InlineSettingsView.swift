//
//  InlineSettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import ApplicationServices
import Combine
import ServiceManagement

// MARK: - Inline Settings View

/// 内联设置视图 — 嵌入 MaxExpand 设置标签页，深色背景适配
struct InlineSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newDomain = ""
    @State private var selectedSection: SettingSection = .general
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var recordingAction: HotkeyAction?
    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    enum SettingSection: String, CaseIterable {
        case general = "通用"
        case shortcuts = "快捷键"
        case about = "关于"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 分段选择器
            Picker("", selection: $selectedSection) {
                ForEach(SettingSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, Theme.Spacing.sm)

            // 内容
            ScrollView {
                switch selectedSection {
                case .general: generalSection
                case .shortcuts: shortcutsSection
                case .about: aboutSection
                }
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 外观
            settingsGroup("外观") {
                settingsRow("语言") {
                    LanguageSettingsView()
                        .environment(\.colorScheme, .dark)
                }

                settingsRow("开机自启动") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("灵动岛透明度")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text("\(Int(settings.islandOpacity * 100))%")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textTertiary)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.islandOpacity, in: 0.1...1.0, step: 0.05)
                        .tint(.white.opacity(0.5))
                }
            }

            // 动画
            settingsGroup("动画") {
                settingsRow("动画速度") {
                    Picker("", selection: $settings.animationSpeed) {
                        ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                settingsRow("弹簧动画") {
                    Toggle("", isOn: $settings.springAnimation)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            // 剪贴板
            settingsGroup("剪贴板") {
                settingsRow("链接检测") {
                    Toggle("", isOn: $settings.clipboardEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                settingsRow("URL 检测模式") {
                    Picker("", selection: $settings.clipboardUrlDetectMode) {
                        Text("仅 HTTPS").tag(ClipboardUrlDetectMode.httpsOnly)
                        Text("HTTP + HTTPS").tag(ClipboardUrlDetectMode.httpHttps)
                        Text("仅域名").tag(ClipboardUrlDetectMode.domainOnly)
                    }
                    .frame(width: 120)
                }

                // 域名黑名单
                VStack(alignment: .leading, spacing: 6) {
                    Text("域名黑名单")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.textSecondary)

                    if settings.blacklistedDomains.isEmpty {
                        Text("暂无")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                    } else {
                        ForEach(Array(settings.blacklistedDomains.sorted()), id: \.self) { domain in
                            HStack {
                                Text(domain)
                                    .font(.system(size: Theme.FontSize.caption))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Button {
                                    settings.blacklistedDomains.remove(domain)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textQuaternary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: Theme.Spacing.xs) {
                        TextField("example.com", text: $newDomain)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))

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
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textSecondary)
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 权限状态
            if !accessibilityGranted {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("辅助功能权限未授予")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textPrimary)
                        Text("快捷键不可用，请在系统设置中授权")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                    Button("授权") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.fillSubtle))
                    .buttonStyle(.plain)
                }
                .padding(Theme.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.orange.opacity(0.1)))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("辅助功能权限已授予")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                }
            }

            // 快捷键列表
            settingsGroup("全局快捷键") {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    InlineHotkeyRow(
                        action: action,
                        binding: settings.hotkeyBindings[action] ?? KeyCombo.defaultBindings[action]!,
                        isRecording: recordingAction == action
                    ) { combo in
                        if let conflict = settings.hotkeyBindings.first(where: { $0.key != action && $0.value == combo }) {
                            settings.hotkeyBindings[conflict.key] = settings.hotkeyBindings[action]
                        }
                        settings.hotkeyBindings[action] = combo
                        recordingAction = nil
                    } onStartRecording: {
                        recordingAction = action
                    }
                }

                Button("恢复默认快捷键") {
                    settings.resetHotkeyBindings()
                    recordingAction = nil
                }
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)
            }
        }
        .onReceive(pollTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.md)

            Image(systemName: "circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary)

            Text("MacIsland")
                .font(.system(size: Theme.FontSize.headline, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            Text("macOS 灵动岛桌面助手")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textQuaternary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                .foregroundColor(.textTertiary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .padding(Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        }
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
            Spacer()
            content()
        }
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

// MARK: - Inline Hotkey Row

private struct InlineHotkeyRow: View {
    let action: HotkeyAction
    let binding: KeyCombo
    let isRecording: Bool
    let onCapture: (KeyCombo) -> Void
    let onStartRecording: () -> Void

    var body: some View {
        HStack {
            Text(action.displayName)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
            Spacer()
            InlineKeyRecorder(
                isRecording: isRecording,
                displayString: binding.displayString,
                onCapture: onCapture,
                onStartRecording: onStartRecording
            )
        }
    }
}

// MARK: - Inline Key Recorder

private struct InlineKeyRecorder: NSViewRepresentable {
    let isRecording: Bool
    let displayString: String
    let onCapture: (KeyCombo) -> Void
    let onStartRecording: () -> Void

    func makeNSView(context: Context) -> InlineKeyRecorderNSView {
        let view = InlineKeyRecorderNSView()
        view.onCapture = onCapture
        view.onStartRecording = onStartRecording
        return view
    }

    func updateNSView(_ nsView: InlineKeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onCapture = onCapture
        nsView.displayString = displayString
        nsView.updateVisual()
        if isRecording { nsView.window?.makeFirstResponder(nsView) }
    }
}

private class InlineKeyRecorderNSView: NSView {
    var isRecording = false
    var displayString = ""
    var onCapture: ((KeyCombo) -> Void)?
    var onStartRecording: (() -> Void)?

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
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
        updateVisual()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateVisual() {
        if isRecording {
            label.stringValue = "按下…"
            label.textColor = .controlAccentColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        } else {
            label.stringValue = displayString
            label.textColor = .labelColor
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { self }
    override func mouseDown(with event: NSEvent) { if !isRecording { onStartRecording?() } }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modOnlyKeys: Set<UInt16> = [0x37, 0x38, 0x3A, 0x3B]
        if modOnlyKeys.contains(event.keyCode) { return }
        if event.keyCode == 0x35 { isRecording = false; updateVisual(); return }
        let nonModFlags = flags.subtracting([.function, .numericPad])
        guard !nonModFlags.isEmpty else { NSSound.beep(); return }
        onCapture?(KeyCombo(modifiers: flags.rawValue, keyCode: event.keyCode))
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts = ""
        if flags.contains(.control) { parts += "⌃" }
        if flags.contains(.option)  { parts += "⌥" }
        if flags.contains(.shift)   { parts += "⇧" }
        if flags.contains(.command) { parts += "⌘" }
        label.stringValue = parts.isEmpty ? "按下…" : parts
    }
}
