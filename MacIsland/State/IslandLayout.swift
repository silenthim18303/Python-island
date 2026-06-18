//
//  IslandLayout.swift
//  MacIsland
//
//  各形态的窗口尺寸与圆角布局 — 全部严格固定，无动态计算
//

import Foundation
import AppKit

// MARK: - Window Size Configuration

/// 各形态的窗口尺寸与圆角布局
enum IslandLayout {

    // MARK: - Idle 系列固定尺寸

    /// 基础: 时间(50) + 日期(70) + 内边距(40) = 160
    private static let baseWidth: CGFloat = 160
    /// 音乐区宽度: 波形图标 + 歌词/歌曲名
    private static let musicExtra: CGFloat = 250
    /// 番茄钟徽章宽度
    private static let clock1Extra: CGFloat = 80
    /// 倒计时徽章宽度
    private static let clock2Extra: CGFloat = 80
    static let idleHeight: CGFloat = 30

    /// 各 idle 组合的固定宽度
    /// .idle = 160 → 210 (clamp min)
    static let idleWidth: CGFloat         = 210   // 无音乐 无番茄 无倒计时
    static let idleMusicWidth: CGFloat    = 490   // +音乐
    static let idleClock1Width: CGFloat   = 290   // +番茄钟
    static let idleClock2Width: CGFloat   = 290   // +倒计时
    static let idleClock1MusicWidth: CGFloat  = 570  // +番茄钟+音乐
    static let idleMusicClock2Width: CGFloat  = 570  // +音乐+倒计时
    static let idleClock1Clock2Width: CGFloat = 370  // +番茄钟+倒计时
    static let idleClock1MusicClock2Width: CGFloat = 650  // 全部

    // MARK: - 其他形态固定尺寸

    static let hoverWidth: CGFloat = 340
    static let hoverHeight: CGFloat = 80
    static let expandedWidth: CGFloat = 460
    static let expandedHeight: CGFloat = 280
    static let maxExpandWidth: CGFloat = 660
    static let maxExpandHeight: CGFloat = 520
    static let notificationWidth: CGFloat = 380
    static let notificationHeight: CGFloat = 80

    /// 横向态每侧内容区宽度（WideNotchLayout 使用）
    static let wideSideWidth: CGFloat = 100

    // MARK: - 计算尺寸

    static var notchHeight: CGFloat {
        let top = NSScreen.main?.safeAreaInsets.top ?? 0
        return top > 0 ? top : idleHeight
    }

    /// 各形态目标尺寸（严格固定）
    static func size(for state: IslandState) -> CGSize {
        let h = notchHeight
        switch state {
        case .idle:                     return CGSize(width: idleWidth, height: h)
        case .idleMusic:                return CGSize(width: idleMusicWidth, height: h)
        case .idleClock1:               return CGSize(width: idleClock1Width, height: h)
        case .idleClock2:               return CGSize(width: idleClock2Width, height: h)
        case .idleClock1Music:          return CGSize(width: idleClock1MusicWidth, height: h)
        case .idleMusicClock2:          return CGSize(width: idleMusicClock2Width, height: h)
        case .idleClock1Clock2:         return CGSize(width: idleClock1Clock2Width, height: h)
        case .idleClock1MusicClock2:    return CGSize(width: idleClock1MusicClock2Width, height: h)
        case .hover:                    return CGSize(width: hoverWidth, height: hoverHeight)
        case .expanded:                 return CGSize(width: expandedWidth, height: expandedHeight)
        case .maxExpand:                return CGSize(width: maxExpandWidth, height: maxExpandHeight)
        case .notification:             return CGSize(width: notificationWidth, height: notificationHeight)
        }
    }

    /// 该形态是否按内容自适应高度
    static func isHeightAdaptive(_ state: IslandState) -> Bool {
        switch state {
        case .hover, .notification, .expanded: return true
        default: return false
        }
    }

    /// 各形态圆角半径
    static func cornerRadius(for state: IslandState) -> CGFloat {
        switch state {
        case .idle, .idleMusic, .idleClock1, .idleClock2,
             .idleClock1Music, .idleMusicClock2,
             .idleClock1Clock2, .idleClock1MusicClock2:
            return notchHeight / 2.0
        case .hover, .notification:
            return hoverHeight * 0.4
        case .expanded, .maxExpand:
            return Theme.Radius.lg
        }
    }
}

// MARK: - Notch Info

enum NotchInfo {
    static var hasNotch: Bool {
        (NSScreen.main?.safeAreaInsets.top ?? 0) > 0
    }

    static var height: CGFloat {
        let top = NSScreen.main?.safeAreaInsets.top ?? 0
        return top > 0 ? top : IslandLayout.idleHeight
    }

    static var width: CGFloat {
        guard let screen = NSScreen.main, screen.safeAreaInsets.top > 0 else {
            return 210
        }
        let full = screen.frame.width
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let notch = full - left - right
        return notch > 0 ? notch : 210
    }
}
