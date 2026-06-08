//
//  VoiceServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation

// MARK: - Voice Command

enum VoiceCommand: String, CaseIterable {
    case play = "播放"
    case pause = "暂停"
    case next = "下一首"
    case previous = "上一首"
    case expand = "展开"
    case collapse = "收起"
    case show = "显示"
    case hide = "隐藏"
    case weather = "天气"
    case timer = "计时器"
    case todo = "待办"
    case help = "帮助"

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .play: return "播放音乐"
        case .pause: return "暂停音乐"
        case .next: return "下一首歌曲"
        case .previous: return "上一首歌曲"
        case .expand: return "展开灵动岛"
        case .collapse: return "收起灵动岛"
        case .show: return "显示灵动岛"
        case .hide: return "隐藏灵动岛"
        case .weather: return "播报天气"
        case .timer: return "播报计时器状态"
        case .todo: return "播报待办事项"
        case .help: return "显示帮助"
        }
    }
}

// MARK: - Voice State

enum VoiceState: String {
    case idle = "空闲"
    case listening = "监听中"
    case processing = "处理中"
    case speaking = "播报中"
    case error = "错误"

    var displayName: String { rawValue }
    var systemImage: String {
        switch self {
        case .idle: return "mic.slash"
        case .listening: return "mic.fill"
        case .processing: return "gear"
        case .speaking: return "speaker.wave.2.fill"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Voice Service Protocol

protocol VoiceServiceProtocol: AnyObject {
    /// 当前语音状态
    var state: VoiceState { get }
    /// 是否正在监听
    var isListening: Bool { get }
    /// 是否正在播报
    var isSpeaking: Bool { get }
    /// 最近识别的文本
    var recognizedText: String { get }
    /// 语音控制是否启用
    var isEnabled: Bool { get set }
    /// 语音播报是否启用
    var isSpeechEnabled: Bool { get set }
    /// 唤醒词
    var wakeWord: String { get set }

    func startListening()
    func stopListening()
    func speak(_ text: String)
    func stopSpeaking()
    func processCommand(_ text: String)
}
