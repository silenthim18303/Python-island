//
//  AppSettings.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI
import Combine

// MARK: - App Settings

/// 全局共享设置 — UserDefaults 持久化，灵动岛与设置窗口共用同一数据源
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var animationSpeed: AnimationSpeed {
        didSet { defaults.set(animationSpeed.rawValue, forKey: Keys.animationSpeed) }
    }
    @Published var springAnimation: Bool {
        didSet { defaults.set(springAnimation, forKey: Keys.springAnimation) }
    }
    @Published var clipboardEnabled: Bool {
        didSet { defaults.set(clipboardEnabled, forKey: Keys.clipboardEnabled) }
    }
    /// 自定义快捷键绑定（HotkeyAction → KeyCombo），UserDefaults JSON 持久化
    @Published var hotkeyBindings: [HotkeyAction: KeyCombo] {
        didSet { Self.saveHotkeyBindings(hotkeyBindings, defaults: defaults) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let animationSpeed = "animationSpeed"
        static let springAnimation = "springAnimation"
        static let clipboardEnabled = "clipboardEnabled"
        static let hotkeyBindings = "hotkeyBindings"
    }

    private init() {
        animationSpeed = (defaults.string(forKey: Keys.animationSpeed))
            .flatMap(AnimationSpeed.init) ?? .medium
        springAnimation = defaults.object(forKey: Keys.springAnimation) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Keys.clipboardEnabled) as? Bool ?? true
        hotkeyBindings = Self.loadHotkeyBindings(defaults: defaults)
    }

    // MARK: - Hotkey Bindings Persistence

    private static func loadHotkeyBindings(defaults: UserDefaults) -> [HotkeyAction: KeyCombo] {
        guard let data = defaults.data(forKey: Keys.hotkeyBindings),
              let decoded = try? JSONDecoder().decode([HotkeyAction: KeyCombo].self, from: data)
        else {
            return KeyCombo.defaultBindings
        }
        // 补充缺失的新 action（升级兼容）
        var bindings = decoded
        for action in HotkeyAction.allCases where bindings[action] == nil {
            bindings[action] = KeyCombo.defaultBindings[action]
        }
        return bindings
    }

    private static func saveHotkeyBindings(_ bindings: [HotkeyAction: KeyCombo], defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: Keys.hotkeyBindings)
        }
    }

    /// 恢复所有快捷键为默认值
    func resetHotkeyBindings() {
        hotkeyBindings = KeyCombo.defaultBindings
    }
}
