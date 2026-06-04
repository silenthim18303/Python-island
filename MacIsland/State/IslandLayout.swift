//
//  IslandLayout.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit

// MARK: - Window Size Configuration

/// 各形态的窗口尺寸与圆角布局（响应式，基于当前屏幕尺寸动态计算）
enum IslandLayout {

    // MARK: - Screen Helpers

    /// 当前屏幕宽度
    private static var screenW: CGFloat {
        (NSScreen.main ?? NSScreen.screens[0]).frame.width
    }

    /// 当前屏幕高度
    private static var screenH: CGFloat {
        (NSScreen.main ?? NSScreen.screens[0]).frame.height
    }

    /// 限制值不超出屏幕比例上限
    private static func clamped(_ value: CGFloat, maxRatio: CGFloat) -> CGFloat {
        min(value, screenW * maxRatio)
    }

    // MARK: - Fixed Base Values

    static let idleHeight: CGFloat = 30
    static let compactIdleWidth: CGFloat = 180

    /// 横向态每侧内容区宽度（基于刘海宽度比例）
    static var wideSideWidth: CGFloat {
        min(NotchInfo.width * 0.15, 100)
    }

    /// 无刘海机型的横向态中间留白（屏幕宽度的 15%）
    static var wideNoNotchGap: CGFloat {
        screenW * 0.15
    }

    // MARK: - Responsive Sizes

    /// hover 尺寸 — 宽度不超过屏幕 25%
    static var hover: CGSize {
        CGSize(width: clamped(340, maxRatio: 0.25), height: 80)
    }

    /// expanded 尺寸 — 宽度不超过屏幕 35%
    static var expanded: CGSize {
        CGSize(width: clamped(460, maxRatio: 0.35), height: 280)
    }

    /// maxExpand 尺寸 — 宽度不超过屏幕 50%，高度不超过屏幕 60%
    static var maxExpand: CGSize {
        CGSize(
            width: clamped(660, maxRatio: 0.5),
            height: min(520, screenH * 0.6)
        )
    }

    /// notification 尺寸 — 宽度不超过屏幕 28%
    static var notification: CGSize {
        CGSize(width: clamped(380, maxRatio: 0.28), height: 80)
    }

    /// 空闲态尺寸 — 无内容时紧凑，有计时器/歌词时自动扩展宽度
    static func idleSize(hasTimer: Bool, hasLyrics: Bool) -> CGSize {
        let height = NotchInfo.height
        if hasTimer || hasLyrics {
            // 有内容时扩展宽度，但不超过屏幕 30%
            return CGSize(width: clamped(380, maxRatio: 0.30), height: height)
        }
        return CGSize(width: compactIdleWidth, height: height)
    }

    /// 空闲态尺寸（无内容时的默认值）
    static var idle: CGSize {
        CGSize(width: compactIdleWidth, height: NotchInfo.height)
    }

    /// 横向绕刘海尺寸 — 宽度绕开刘海两侧，高度与物理刘海等高，供歌词/倒计时复用
    static var wideSize: CGSize {
        CGSize(width: NotchInfo.width + wideSideWidth * 2, height: NotchInfo.height)
    }

    // MARK: - State Queries

    /// 根据形态获取目标尺寸（自适应态返回的高度为最小高度）
    static func size(for state: IslandState) -> CGSize {
        switch state {
        case .idle: return idle
        case .hover: return hover
        case .expanded: return expanded
        case .maxExpand: return maxExpand
        case .notification: return notification
        case .lyrics, .countdown: return wideSize
        }
    }

    /// 该形态是否按内容自适应高度（宽度恒定，仅高度随内容变化）
    static func isHeightAdaptive(_ state: IslandState) -> Bool {
        switch state {
        case .hover, .notification, .expanded: return true
        default: return false
        }
    }

    /// 根据形态获取圆角半径（按高度比例缩放）
    static func cornerRadius(for state: IslandState) -> CGFloat {
        switch state {
        case .idle:
            return idle.height / 2.0
        case .lyrics, .countdown:
            return wideSize.height / 2.0
        case .hover, .notification:
            return size(for: state).height * 0.4
        case .expanded, .maxExpand:
            return Theme.Radius.lg
        }
    }
}

// MARK: - Notch Info

/// 主屏物理刘海信息 — 用于横向态绕开刘海布局
enum NotchInfo {
    /// 主屏是否存在物理刘海
    static var hasNotch: Bool {
        (NSScreen.main?.safeAreaInsets.top ?? 0) > 0
    }

    /// 刘海高度（无刘海机型回退为紧凑态高度）
    static var height: CGFloat {
        let top = NSScreen.main?.safeAreaInsets.top ?? 0
        return top > 0 ? top : IslandLayout.idleHeight
    }

    /// 刘海宽度（无刘海机型回退为屏幕比例留白）
    static var width: CGFloat {
        guard let screen = NSScreen.main, screen.safeAreaInsets.top > 0 else {
            return IslandLayout.wideNoNotchGap
        }
        // 刘海宽度 = 屏幕宽 - 左侧可用区 - 右侧可用区
        let full = screen.frame.width
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let notch = full - left - right
        return notch > 0 ? notch : IslandLayout.wideNoNotchGap
    }
}

