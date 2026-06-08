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

/// 原生偏好设置窗口 — 左侧分类侧栏 + 右侧表单，顶部支持搜索
struct SettingsView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selection: SettingsCategory = .appearance
    @State private var searchQuery = ""

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 搜索时仅展示命中的分类
    private var visibleCategories: [SettingsCategory] {
        if isSearching {
            return SettingsCatalog.search(searchQuery).map(\.category)
        }
        return SettingsCategory.allCases
    }

    var body: some View {
        NavigationSplitView {
            List(visibleCategories, selection: $selection) { category in
                Label(category.title, systemImage: category.systemImage)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            ScrollView {
                detailContent
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .searchable(text: $searchQuery, placement: .sidebar, prompt: L10n.search)
        .onChange(of: visibleCategories) { _, categories in
            // 搜索过滤后，若当前选中项被过滤掉，跳到第一个命中项
            if !categories.contains(selection), let first = categories.first {
                selection = first
            }
        }
        .frame(minWidth: 620, idealWidth: 660, minHeight: 420, idealHeight: 460)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .appearance, .wallpaper, .animation, .clipboard,
             .music, .weather, .notifications, .community:
            GeneralSettingsView(category: selection)
        case .shortcuts:
            ShortcutsSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - Settings Description Helpers

/// 设置项标题 + 说明小字（取自 SettingsCatalog），统一原生窗口文案
private struct SettingLabel: View {
    let key: String

    var body: some View {
        let meta = SettingItemMeta.meta(key)
        VStack(alignment: .leading, spacing: 2) {
            Text(meta?.title ?? key)
            if let desc = meta?.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private func settingHint(_ key: String) -> String {
    SettingItemMeta.meta(key)?.hint ?? ""
}

// MARK: - General

private struct GeneralSettingsView: View {
    let category: SettingsCategory
    @ObservedObject private var settings = AppSettings.shared
    @State private var newDomain: String = ""
    @State private var communityUsername = UserDefaults.standard.string(forKey: "communityUploadUsername") ?? ""

    var body: some View {
        Form {
            switch category {
            case .appearance:    appearanceSection
            case .wallpaper:     wallpaperSection
            case .animation:     animationSection
            case .clipboard:     clipboardSection
            case .music:         musicSection
            case .weather:       weatherSection
            case .notifications: notificationsSection
            case .community:     communitySection
            default:             EmptyView()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Appearance

    @ViewBuilder private var appearanceSection: some View {
        Section(L10n.settingsAppearance) {
            LabeledContent {
                Picker("", selection: $settings.appearanceMode) {
                    ForEach(AppAppearance.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            } label: { SettingLabel(key: "appearanceMode") }

            LabeledContent {
                AccentColorPicker(selection: $settings.accentColorOption)
            } label: { SettingLabel(key: "accentColor") }

            LabeledContent { LanguageSettingsView().labelsHidden() }
            label: { SettingLabel(key: "language") }

            Toggle(isOn: $settings.launchAtLogin) { SettingLabel(key: "launchAtLogin") }
                .onChange(of: settings.launchAtLogin) { _, v in setLaunchAtLogin(v) }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SettingLabel(key: "islandOpacity")
                    Spacer()
                    Text("\(Int(settings.islandOpacity * 100))%")
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $settings.islandOpacity, in: 0.1...1.0, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    SettingLabel(key: "wallpaperOpacity")
                    Spacer()
                    Text("\(Int(settings.wallpaperOpacity * 100))%")
                        .foregroundColor(.secondary).monospacedDigit()
                }
                Slider(value: $settings.wallpaperOpacity, in: 0.0...1.0, step: 0.05)
            }
        }
    }

    // MARK: - Wallpaper

    @ViewBuilder private var wallpaperSection: some View {
        Section(L10n.wallpaperPath) {
            VStack(alignment: .leading, spacing: 6) {
                SettingLabel(key: "customWallpaperPath")
                HStack {
                    TextField(settingHint("customWallpaperPath"), text: $settings.customWallpaperPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                    Button {
                        selectWallpaperPath()
                    } label: { Image(systemName: "folder") }
                }
                if settings.customWallpaperPath.isEmpty {
                    Text(L10n.wallpaperPathDefault)
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Button(L10n.restore) { settings.clearCustomWallpaperDirectory() }
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Animation

    @ViewBuilder private var animationSection: some View {
        Section(L10n.settingsAnimation) {
            Picker(selection: $settings.animationSpeed) {
                ForEach(AnimationSpeed.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            } label: { SettingLabel(key: "animationSpeed") }
                .pickerStyle(.segmented)

            Toggle(isOn: $settings.springAnimation) { SettingLabel(key: "springAnimation") }
        }
    }

    // MARK: - Clipboard

    @ViewBuilder private var clipboardSection: some View {
        Section(L10n.settingsClipboard) {
            Toggle(isOn: $settings.clipboardEnabled) { SettingLabel(key: "clipboardEnabled") }

            Picker(selection: $settings.clipboardUrlDetectMode) {
                Text(L10n.settingsHttpsOnly).tag(ClipboardUrlDetectMode.httpsOnly)
                Text(L10n.settingsHttpHttps).tag(ClipboardUrlDetectMode.httpHttps)
                Text(L10n.settingsDomainOnly).tag(ClipboardUrlDetectMode.domainOnly)
            } label: { SettingLabel(key: "clipboardUrlDetectMode") }

            VStack(alignment: .leading, spacing: 6) {
                SettingLabel(key: "blacklistedDomains")
                if settings.blacklistedDomains.isEmpty {
                    Text(L10n.settingsBlacklistEmpty).font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(Array(settings.blacklistedDomains.sorted()), id: \.self) { domain in
                        HStack {
                            Text(domain).font(.callout)
                            Spacer()
                            Button {
                                settings.blacklistedDomains.remove(domain)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    TextField(settingHint("blacklistedDomains"), text: $newDomain)
                        .textFieldStyle(.roundedBorder)
                    Button(L10n.add) { addDomain() }
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Music

    @ViewBuilder private var musicSection: some View {
        Section(L10n.musicLyrics) {
            Picker(selection: $settings.preferredLyricsSource) {
                Text(L10n.translateAuto).tag("auto")
                Text(L10n.musicNetease).tag("netease")
                Text(L10n.musicQQ).tag("qqmusic")
                Text(L10n.musicKugou).tag("kugou")
                Text(L10n.musicLRCLIB).tag("lrclib")
            } label: { SettingLabel(key: "preferredLyricsSource") }
        }
    }

    // MARK: - Weather

    @ViewBuilder private var weatherSection: some View {
        Section(L10n.weatherTitle) {
            LabeledContent {
                SecureField(settingHint("weatherAPIKey"), text: $settings.weatherAPIKey)
                    .textFieldStyle(.roundedBorder).frame(width: 220)
            } label: { SettingLabel(key: "weatherAPIKey") }

            LabeledContent {
                TextField(settingHint("weatherManualCity"), text: $settings.weatherManualCity)
                    .textFieldStyle(.roundedBorder).frame(width: 160)
            } label: { SettingLabel(key: "weatherManualCity") }

            if !settings.weatherManualCity.isEmpty {
                LabeledContent {
                    TextField(settingHint("weatherManualLocationID"), text: $settings.weatherManualLocationID)
                        .textFieldStyle(.roundedBorder).frame(width: 160)
                } label: { SettingLabel(key: "weatherManualLocationID") }

                Button(L10n.weatherClear) {
                    settings.weatherManualCity = ""
                    settings.weatherManualLocationID = ""
                }
                .font(.caption)
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder private var notificationsSection: some View {
        NotificationCenterView()
    }

    // MARK: - Community

    @ViewBuilder private var communitySection: some View {
        Section(L10n.settingsCommunity) {
            LabeledContent {
                TextField(settingHint("communityUploadUsername"), text: $communityUsername)
                    .textFieldStyle(.roundedBorder).frame(width: 160)
                    .onSubmit {
                        UserDefaults.standard.set(communityUsername, forKey: "communityUploadUsername")
                    }
            } label: { SettingLabel(key: "communityUploadUsername") }
        }
    }

    // MARK: - Actions

    private func addDomain() {
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

    private func selectWallpaperPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = L10n.wallpaperSelect
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.setCustomWallpaperDirectory(url)
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
                print("Login Item error: \(error)")
            }
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var recordingAction: HotkeyAction?
    @State private var conflictAlert: ConflictAlert?
    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    /// 冲突弹窗数据
    private struct ConflictAlert: Identifiable {
        let id = UUID()
        let newAction: HotkeyAction
        let conflictAction: HotkeyAction
        let combo: KeyCombo
    }

    var body: some View {
        Form {
            // 权限状态
            Section {
                if !accessibilityGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.shortcutPermissionDenied)
                                .font(.callout)
                            Text(L10n.shortcutOpenSettings)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(L10n.shortcutOpenSettings) {
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
                        Text(L10n.shortcutPermissionGranted)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 快捷键绑定
            Section(L10n.shortcutTitle) {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    HotkeyRow(
                        action: action,
                        binding: settings.hotkeyBindings[action] ?? KeyCombo.defaultBindings[action]!,
                        isRecording: recordingAction == action
                    ) { combo in
                        handleCapture(action: action, combo: combo)
                    } onStartRecording: {
                        recordingAction = action
                    }
                }

                // 恢复默认
                Button(L10n.shortcutReset) {
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
        .alert(item: $conflictAlert) { alert in
            Alert(
                title: Text(L10n.shortcutConflict),
                message: Text("「\(alert.combo.displayString)」\(L10n.shortcutConflictMsg)「\(alert.conflictAction.displayName)」。"),
                primaryButton: .default(Text(L10n.shortcutSwap)) {
                    // 交换两者
                    let oldBinding = settings.hotkeyBindings[alert.newAction]
                    settings.hotkeyBindings[alert.newAction] = alert.combo
                    settings.hotkeyBindings[alert.conflictAction] = oldBinding
                    recordingAction = nil
                },
                secondaryButton: .cancel(Text(L10n.cancel)) {
                    recordingAction = nil
                }
            )
        }
    }

    /// 处理快捷键捕获 — 检测冲突并弹窗
    private func handleCapture(action: HotkeyAction, combo: KeyCombo) {
        // 检查是否有冲突
        if let conflictEntry = settings.hotkeyBindings.first(where: { $0.key != action && $0.value == combo }) {
            conflictAlert = ConflictAlert(
                newAction: action,
                conflictAction: conflictEntry.key,
                combo: combo
            )
        } else {
            // 无冲突，直接设置
            settings.hotkeyBindings[action] = combo
            recordingAction = nil
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
    private var pulseAnimation: CABasicAnimation?

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
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1.5
        updateVisualState()
    }

    /// 更新视觉状态（录制中高亮 + 脉冲动画 / 正常显示）
    func updateVisualState() {
        if isRecording {
            label.stringValue = L10n.shortcutPressKey
            label.textColor = .controlAccentColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            startPulseAnimation()
        } else {
            label.stringValue = displayString
            label.textColor = .labelColor
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            layer?.borderColor = NSColor.clear.cgColor
            stopPulseAnimation()
        }
    }

    /// 脉冲动画 — 录制时边框呼吸效果
    private func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "borderColor")
        pulse.fromValue = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        pulse.toValue = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer?.add(pulse, forKey: "pulseBorder")
        self.pulseAnimation = pulse
    }

    private func stopPulseAnimation() {
        layer?.removeAnimation(forKey: "pulseBorder")
        self.pulseAnimation = nil
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

        // 允许所有按键组合（包括无修饰键的单键）
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
        label.stringValue = parts.isEmpty ? L10n.shortcutPressKey : parts
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.appAccent)

            Text("MacIsland")
                .font(.title2.bold())

            Text("\(L10n.version) \(version)")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Accent Color Picker

struct AccentColorPicker: View {
    @Binding var selection: AccentColorOption

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentColorOption.allCases) { option in
                Button { selection = option } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: selection == option ? 2.5 : 0)
                        )
                        .shadow(color: selection == option ? option.color.opacity(0.4) : .clear, radius: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
