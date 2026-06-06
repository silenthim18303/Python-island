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
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var newDomain = ""
    @State private var communityUsername = UserDefaults.standard.string(forKey: "communityUploadUsername") ?? ""
    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var searchQuery = ""
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var recordingAction: HotkeyAction?
    @State private var conflictAlert: InlineConflictAlert?
    private let pollTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    /// 冲突弹窗数据
    private struct InlineConflictAlert: Identifiable {
        let id = UUID()
        let newAction: HotkeyAction
        let conflictAction: HotkeyAction
        let combo: KeyCombo
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            searchBar

            if isSearching {
                ScrollView { searchResults }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    sidebar
                    ScrollView { categoryContent(selectedCategory) }
                }
            }
        }
        .onReceive(pollTimer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
            TextField("\(L10n.search)…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textPrimary)
            if isSearching {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.textQuaternary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 12))
                            .frame(width: 16)
                        Text(category.title)
                            .font(.system(size: Theme.FontSize.caption))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(selectedCategory == category ? .textPrimary : .textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(selectedCategory == category ? Color.fillStrong : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 112)
    }

    // MARK: - Category Content Router

    @ViewBuilder
    private func categoryContent(_ category: SettingsCategory) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            switch category {
            case .appearance:    appearanceSection
            case .wallpaper:     wallpaperSection
            case .animation:     animationSection
            case .clipboard:     clipboardSection
            case .music:         musicSection
            case .weather:       weatherSection
            case .notifications: notificationsSection
            case .community:     communitySection
            case .shortcuts:     shortcutsSection
            case .about:         aboutSection
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        let hits = SettingsCatalog.search(searchQuery)
        return VStack(spacing: Theme.Spacing.md) {
            if hits.isEmpty {
                Text(L10n.search + " - " + L10n.noData)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.lg)
            } else {
                ForEach(hits) { hit in
                    Button {
                        selectedCategory = hit.category
                        searchQuery = ""
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: hit.category.systemImage)
                                .font(.system(size: 12))
                                .frame(width: 16)
                                .foregroundColor(.textSecondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.category.title)
                                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                if !hit.items.isEmpty {
                                    Text(hit.items.map(\.title).joined(separator: " · "))
                                        .font(.system(size: Theme.FontSize.caption2))
                                        .foregroundColor(.textTertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.textQuaternary)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.settingsAppearance) {
                describedRow("appearanceMode") {
                    Picker("", selection: $settings.appearanceMode) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }

                describedRow("accentColor") {
                    InlineAccentColorPicker(selection: $settings.accentColorOption)
                }

                describedRow("language") {
                    LanguageSettingsView()
                        .environment(\.colorScheme, .dark)
                }

                describedRow("launchAtLogin") {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .onChange(of: settings.launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                }

                sliderRow("islandOpacity",
                          value: $settings.islandOpacity,
                          range: 0.1...1.0,
                          percentText: "\(Int(settings.islandOpacity * 100))%")

                sliderRow("wallpaperOpacity",
                          value: $settings.wallpaperOpacity,
                          range: 0.0...1.0,
                          percentText: "\(Int(settings.wallpaperOpacity * 100))%")
            }
        }
    }

    // MARK: - Wallpaper Section

    private var wallpaperSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.wallpaperPath) {
                VStack(alignment: .leading, spacing: 6) {
                    descriptionText("customWallpaperPath")

                    HStack(spacing: 6) {
                        TextField(SettingItemMeta.meta("customWallpaperPath")?.hint ?? "",
                                  text: $settings.customWallpaperPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.FontSize.caption2, design: .monospaced))
                            .foregroundColor(.textPrimary)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))

                        Button {
                            selectWallpaperPath()
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if settings.customWallpaperPath.isEmpty {
                        Text(L10n.wallpaperPathDefault)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                    } else {
                        Button(L10n.restore) {
                            settings.customWallpaperPath = ""
                        }
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(Color.appAccent)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Animation Section

    private var animationSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.settingsAnimation) {
                describedRow("animationSpeed") {
                    Picker("", selection: $settings.animationSpeed) {
                        ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                describedRow("springAnimation") {
                    Toggle("", isOn: $settings.springAnimation)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    // MARK: - Clipboard Section

    private var clipboardSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.settingsClipboard) {
                describedRow("clipboardEnabled") {
                    Toggle("", isOn: $settings.clipboardEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }

                describedRow("clipboardUrlDetectMode") {
                    Picker("", selection: $settings.clipboardUrlDetectMode) {
                        Text(L10n.settingsHttpsOnly).tag(ClipboardUrlDetectMode.httpsOnly)
                        Text(L10n.settingsHttpHttps).tag(ClipboardUrlDetectMode.httpHttps)
                        Text(L10n.settingsDomainOnly).tag(ClipboardUrlDetectMode.domainOnly)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                blacklistEditor
            }
        }
    }

    private var blacklistEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.settingsBlacklist)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.textSecondary)
            descriptionText("blacklistedDomains")

            if settings.blacklistedDomains.isEmpty {
                Text(L10n.settingsBlacklistEmpty)
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
                TextField(SettingItemMeta.meta("blacklistedDomains")?.hint ?? "", text: $newDomain)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))

                Button(L10n.add) {
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

    // MARK: - Music Section

    private var musicSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.musicLyrics) {
                describedRow("preferredLyricsSource") {
                    Picker("", selection: $settings.preferredLyricsSource) {
                        Text(L10n.translateAuto).tag("auto")
                        Text(L10n.musicNetease).tag("netease")
                        Text(L10n.musicQQ).tag("qqmusic")
                        Text(L10n.musicKugou).tag("kugou")
                        Text(L10n.musicLRCLIB).tag("lrclib")
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
            }
        }
    }

    // MARK: - Weather Section

    private var weatherSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.weatherTitle) {
                describedRow("weatherManualCity") {
                    TextField(SettingItemMeta.meta("weatherManualCity")?.hint ?? "",
                              text: $settings.weatherManualCity)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textPrimary)
                        .frame(width: 100)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))
                }

                if !settings.weatherManualCity.isEmpty {
                    describedRow("weatherManualLocationID") {
                        TextField(SettingItemMeta.meta("weatherManualLocationID")?.hint ?? "",
                                  text: $settings.weatherManualLocationID)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textPrimary)
                            .frame(width: 100)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))
                    }

                    Button(L10n.weatherClear) {
                        settings.weatherManualCity = ""
                        settings.weatherManualLocationID = ""
                    }
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textTertiary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        NotificationCenterView()
    }

    // MARK: - Community Section

    private var communitySection: some View {
        VStack(spacing: Theme.Spacing.md) {
            settingsGroup(L10n.settingsCommunity) {
                describedRow("communityUploadUsername") {
                    TextField(SettingItemMeta.meta("communityUploadUsername")?.hint ?? "",
                              text: $communityUsername)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textPrimary)
                        .frame(width: 100)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))
                        .onSubmit {
                            UserDefaults.standard.set(communityUsername, forKey: "communityUploadUsername")
                        }
                }
            }
        }
    }

    // MARK: - Shortcuts Section

    private var shortcutsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if !accessibilityGranted {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.shortcutPermissionDenied)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(.textPrimary)
                        Text(L10n.shortcutOpenSettings)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textTertiary)
                    }
                    Spacer()
                    Button(L10n.shortcutAuth) {
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
                    Text(L10n.shortcutPermissionGranted)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                }
            }

            settingsGroup(L10n.shortcutTitle) {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    InlineHotkeyRow(
                        action: action,
                        binding: settings.hotkeyBindings[action] ?? KeyCombo.defaultBindings[action]!,
                        isRecording: recordingAction == action
                    ) { combo in
                        handleInlineCapture(action: action, combo: combo)
                    } onStartRecording: {
                        recordingAction = action
                    }
                }

                Button(L10n.shortcutReset) {
                    settings.resetHotkeyBindings()
                    recordingAction = nil
                }
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)
            }
        }
        .alert(item: $conflictAlert) { alert in
            Alert(
                title: Text(L10n.shortcutConflict),
                message: Text("「\(alert.combo.displayString)」\(L10n.shortcutConflictMsg)「\(alert.conflictAction.displayName)」。"),
                primaryButton: .default(Text(L10n.shortcutSwap)) {
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
    private func handleInlineCapture(action: HotkeyAction, combo: KeyCombo) {
        if let conflictEntry = settings.hotkeyBindings.first(where: { $0.key != action && $0.value == combo }) {
            conflictAlert = InlineConflictAlert(
                newAction: action,
                conflictAction: conflictEntry.key,
                combo: combo
            )
        } else {
            settings.hotkeyBindings[action] = combo
            recordingAction = nil
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer().frame(height: Theme.Spacing.md)

            Image(systemName: "circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary)

            Text(L10n.aboutTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("\(L10n.version) \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            Text(L10n.aboutSubtitle)
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

    /// 带说明的行：标题 + 控件一行，下方小字说明（取自 SettingsCatalog）
    private func describedRow<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        let meta = SettingItemMeta.meta(key)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(meta?.title ?? key)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textSecondary)
                Spacer()
                content()
            }
            if let desc = meta?.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }

    /// 带说明的滑块行：标题 + 百分比 + 说明 + 滑块
    private func sliderRow(_ key: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           percentText: String) -> some View {
        let meta = SettingItemMeta.meta(key)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meta?.title ?? key)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(percentText)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                    .monospacedDigit()
            }
            if let desc = meta?.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Slider(value: value, in: range, step: 0.05)
                .tint(.white.opacity(0.5))
        }
        .padding(.vertical, 3)
    }

    /// 仅说明小字（用于自定义布局的组，如壁纸路径 / 黑名单）
    @ViewBuilder
    private func descriptionText(_ key: String) -> some View {
        if let desc = SettingItemMeta.meta(key)?.description, !desc.isEmpty {
            Text(desc)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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
                print("Login Item error: \(error)")
            }
        }
    }

    private func selectWallpaperPath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = L10n.wallpaperSelect

        IslandStore.isPanelPresented = true
        let result = panel.runModal()
        IslandStore.isPanelPresented = false

        guard result == .OK, let url = panel.url else { return }
        settings.customWallpaperPath = url.path
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
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1.5
        updateVisual()
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateVisual() {
        if isRecording {
            label.stringValue = L10n.shortcutPressKey
            label.textColor = .controlAccentColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            startPulse()
        } else {
            label.stringValue = displayString
            label.textColor = .labelColor
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            layer?.borderColor = NSColor.clear.cgColor
            stopPulse()
        }
    }

    private func startPulse() {
        let pulse = CABasicAnimation(keyPath: "borderColor")
        pulse.fromValue = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        pulse.toValue = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        layer?.add(pulse, forKey: "pulseBorder")
    }

    private func stopPulse() {
        layer?.removeAnimation(forKey: "pulseBorder")
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
        label.stringValue = parts.isEmpty ? L10n.shortcutPressKey : parts
    }
}

// MARK: - Inline Accent Color Picker

private struct InlineAccentColorPicker: View {
    @Binding var selection: AccentColorOption

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AccentColorOption.allCases) { option in
                Button { selection = option } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(selection == option ? 0.9 : 0), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
