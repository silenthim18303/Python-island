//
//  IslandLayout.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit

// MARK: - Window Size Configuration

/// 各形态的窗口尺寸与圆角布局
enum IslandLayout {
    static let idleHeight: CGFloat = 30
    static let compactIdleWidth: CGFloat = 180
    static let hover = CGSize(width: 300, height: 80)
    static let expanded = CGSize(width: 420, height: 280)
    static let maxExpand = CGSize(width: 600, height: 480)
    static let notification = CGSize(width: 340, height: 80)

    /// 横向态每侧内容区宽度（左右各占一侧，中间让出刘海）
    static let wideSideWidth: CGFloat = 96

    /// 无刘海机型的横向态中间留白
    static let wideNoNotchGap: CGFloat = 180

    /// 空闲态尺寸 — 固定紧凑居中，高度统一为刘海物理高度
    static var idle: CGSize {
        CGSize(width: compactIdleWidth, height: NotchInfo.height)
    }

    /// 横向绕刘海尺寸 — 宽度绕开刘海两侧，高度与物理刘海等高，供歌词/倒计时复用
    static var wideSize: CGSize {
        CGSize(width: NotchInfo.width + wideSideWidth * 2, height: NotchInfo.height)
    }

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
        case .hover, .notification: return true
        default: return false
        }
    }

    /// 根据形态获取圆角半径
    static func cornerRadius(for state: IslandState) -> CGFloat {
        switch state {
        case .idle:
            return idle.height / 2.0
        case .lyrics, .countdown:
            return wideSize.height / 2.0
        case .hover, .notification:
            return 20
        case .expanded, .maxExpand:
            return 22
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

    /// 刘海宽度（无刘海机型回退为预设留白）
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

