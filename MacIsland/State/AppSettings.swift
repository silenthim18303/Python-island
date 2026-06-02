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

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let animationSpeed = "animationSpeed"
        static let springAnimation = "springAnimation"
        static let clipboardEnabled = "clipboardEnabled"
    }

    private init() {
        animationSpeed = (defaults.string(forKey: Keys.animationSpeed))
            .flatMap(AnimationSpeed.init) ?? .medium
        springAnimation = defaults.object(forKey: Keys.springAnimation) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Keys.clipboardEnabled) as? Bool ?? true
    }
}
