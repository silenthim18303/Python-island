//
//  HotkeyServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Hotkey Action

enum HotkeyAction: String, CaseIterable {
    case toggleIsland    // 显示/隐藏岛
    case playPause       // 播放/暂停
    case nextTrack       // 下一首
    case previousTrack   // 上一首

    var defaultKeyCombo: String {
        switch self {
        case .toggleIsland:  return "⌥⌘I"
        case .playPause:     return "⌥⌘P"
        case .nextTrack:     return "⌥⌘→"
        case .previousTrack: return "⌥⌘←"
        }
    }

    var displayName: String {
        switch self {
        case .toggleIsland:  return "显示/隐藏岛"
        case .playPause:     return "播放/暂停"
        case .nextTrack:     return "下一首"
        case .previousTrack: return "上一首"
        }
    }
}

// MARK: - Hotkey Service Protocol

/// 全局快捷键服务 — 监听 ⌥⌘ 系列组合键
protocol HotkeyServiceProtocol: AnyObject {
    func startMonitoring()
    func stopMonitoring()
}
