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
    case idle
    case hover
    case expanded
    case maxExpand
    case notification(title: String, body: String)
    case lyrics
    case countdown
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
