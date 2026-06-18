//
//  VoiceServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation

// MARK: - Voice Command

enum VoiceCommand: String, CaseIterable {
    case expand
    case collapse
    case show
    case hide
    case weather
    case timer
    case todo
    case help
    case stock
    case play
    case pause
    case next
    case previous

    /// 语音触发词（多语言）
    var triggerWords: [String] {
        switch self {
        case .expand: return ["展开", "expand", "展開"]
        case .collapse: return ["收起", "collapse", "折りたたむ"]
        case .show: return ["显示", "show", "表示"]
        case .hide: return ["隐藏", "hide", "隠す"]
        case .weather: return ["天气", "weather", "天気"]
        case .timer: return ["计时器", "timer", "タイマー"]
        case .todo: return ["待办", "todo", "TODO"]
        case .help: return ["帮助", "help", "ヘルプ"]
        case .stock: return ["股票", "股价", "stock", "price"]
        case .play: return ["播放", "play", "再生"]
        case .pause: return ["暂停", "pause", "一時停止"]
        case .next: return ["下一首", "next", "次へ"]
        case .previous: return ["上一首", "previous", "前へ"]
        }
    }

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .expand: return L10n.voiceCmdExpand
        case .collapse: return L10n.voiceCmdCollapse
        case .show: return L10n.voiceCmdShow
        case .hide: return L10n.voiceCmdHide
        case .weather: return L10n.voiceCmdWeather
        case .timer: return L10n.voiceCmdTimer
        case .todo: return L10n.voiceCmdTodo
        case .help: return L10n.voiceCmdHelp
        case .stock: return L10n.voiceCmdStock
        case .play: return L10n.voiceCmdPlay
        case .pause: return L10n.voiceCmdPause
        case .next: return L10n.voiceCmdNext
        case .previous: return L10n.voiceCmdPrevious
        }
    }

    /// 本地化描述
    var description: String {
        switch self {
        case .expand: return L10n.voiceCmdExpandDesc
        case .collapse: return L10n.voiceCmdCollapseDesc
        case .show: return L10n.voiceCmdShowDesc
        case .hide: return L10n.voiceCmdHideDesc
        case .weather: return L10n.voiceCmdWeatherDesc
        case .timer: return L10n.voiceCmdTimerDesc
        case .todo: return L10n.voiceCmdTodoDesc
        case .help: return L10n.voiceCmdHelpDesc
        case .stock: return L10n.voiceCmdStockDesc
        case .play: return L10n.voiceCmdPlayDesc
        case .pause: return L10n.voiceCmdPauseDesc
        case .next: return L10n.voiceCmdNextDesc
        case .previous: return L10n.voiceCmdPreviousDesc
        }
    }

    /// 从文本匹配命令
    static func match(from text: String) -> VoiceCommand? {
        let lowercased = text.lowercased()
        for command in VoiceCommand.allCases {
            if command.triggerWords.contains(where: { lowercased.contains($0.lowercased()) }) {
                return command
            }
        }
        return nil
    }
}

// MARK: - Voice State

enum VoiceState: String {
    case idle
    case listening
    case processing
    case speaking
    case error

    var displayName: String {
        switch self {
        case .idle: return L10n.voiceStateIdle
        case .listening: return L10n.voiceStateListening
        case .processing: return L10n.voiceStateProcessing
        case .speaking: return L10n.voiceStateSpeaking
        case .error: return L10n.voiceStateError
        }
    }

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
