//
//  Theme.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

// MARK: - Design Tokens

/// 统一设计令牌 — 集中管理间距 / 圆角 / 字阶 / 透明度，避免硬编码散落
enum Theme {
    // 间距
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // 圆角
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    // 字号字阶
    enum FontSize {
        static let caption2: CGFloat = 10
        static let caption: CGFloat = 11
        static let body: CGFloat = 13
        static let headline: CGFloat = 15
        static let title: CGFloat = 20
    }

    // 文本前景透明度层级
    enum TextOpacity {
        static let primary: Double = 1.0
        static let secondary: Double = 0.6
        static let tertiary: Double = 0.4
        static let quaternary: Double = 0.25
    }

    // 背景/描边透明度层级
    enum FillOpacity {
        static let subtle: Double = 0.08
        static let strong: Double = 0.15
        static let hairline: Double = 0.12
    }
}

// MARK: - Color Convenience

extension Color {
    static let textPrimary = Color.white.opacity(Theme.TextOpacity.primary)
    static let textSecondary = Color.white.opacity(Theme.TextOpacity.secondary)
    static let textTertiary = Color.white.opacity(Theme.TextOpacity.tertiary)
    static let textQuaternary = Color.white.opacity(Theme.TextOpacity.quaternary)

    static let fillSubtle = Color.white.opacity(Theme.FillOpacity.subtle)
    static let fillStrong = Color.white.opacity(Theme.FillOpacity.strong)
    static let hairline = Color.white.opacity(Theme.FillOpacity.hairline)

    /// 用户自定义强调色
    static var appAccent: Color {
        AppSettings.shared.accentColorOption.color
    }
}

// MARK: - Height Preference Key

/// 用于测量内容固有高度 → 驱动窗口自适应
struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
