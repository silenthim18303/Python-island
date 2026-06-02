//
//  SettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

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
        .frame(width: 420, height: 280)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("功能开关") {
                Toggle("剪贴板链接检测", isOn: $settings.clipboardEnabled)
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
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("全局快捷键") {
                ShortcutRow(keys: "⌥⌘I", label: "显示 / 隐藏灵动岛")
                ShortcutRow(keys: "⌥⌘P", label: "播放 / 暂停")
                ShortcutRow(keys: "⌥⌘→", label: "下一首")
                ShortcutRow(keys: "⌥⌘←", label: "上一首")
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let label: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
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
