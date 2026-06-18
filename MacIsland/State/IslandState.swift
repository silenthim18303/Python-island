//
//  IslandState.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Island UI State

/// 灵动岛 UI 形态
enum IslandState: Equatable {
    case idle                          // 210pt
    case idleMusic                     // 490pt  +音乐
    case idleClock1                    // 290pt  +番茄钟
    case idleClock2                    // 290pt  +倒计时
    case idleClock1Music               // 570pt  +番茄钟+音乐
    case idleMusicClock2               // 570pt  +音乐+倒计时
    case idleClock1Clock2              // 370pt  +番茄钟+倒计时
    case idleClock1MusicClock2         // 650pt  +番茄钟+音乐+倒计时
    case hover
    case expanded
    case maxExpand
    case notification(title: String, body: String, url: String?)

    static func compact(music: Bool, pomodoro: Bool, countdown: Bool) -> IslandState {
        switch (music, pomodoro, countdown) {
        case (false, false, false): return .idle
        case (true,  false, false): return .idleMusic
        case (false, true,  false): return .idleClock1
        case (false, false, true):  return .idleClock2
        case (true,  true,  false): return .idleClock1Music
        case (true,  false, true):  return .idleMusicClock2
        case (false, true,  true):  return .idleClock1Clock2
        case (true,  true,  true):  return .idleClock1MusicClock2
        }
    }

    /// 是否为缩小态（idle 系列）
    var isCompact: Bool {
        switch self {
        case .idle, .idleMusic, .idleClock1, .idleClock2,
             .idleClock1Music, .idleMusicClock2,
             .idleClock1Clock2, .idleClock1MusicClock2:
            return true
        default:
            return false
        }
    }
}

// MARK: - Animation Configuration

/// 动画速度配置
enum AnimationSpeed: String, CaseIterable {
    case slow = "慢速"
    case medium = "中速"
    case fast = "快速"

    var duration: Double {
        switch self {
        case .slow: return 0.6
        case .medium: return 0.4
        case .fast: return 0.25
        }
    }
}
