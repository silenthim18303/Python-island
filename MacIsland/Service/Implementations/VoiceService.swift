//
//  VoiceService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// 语音服务 - 语音输入、语音控制、语音播报
@MainActor
final class VoiceService: NSObject, ObservableObject, VoiceServiceProtocol {
    @Published private(set) var state: VoiceState = .idle
    @Published private(set) var isListening = false
    @Published private(set) var isSpeaking = false
    @Published private(set) var recognizedText = ""
    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                startContinuousListening()
            } else {
                stopListening()
            }
        }
    }
    @Published var isSpeechEnabled = true
    @Published var wakeWord = "嘿，灵动岛"

    // TTS 配置
    @Published var selectedVoiceIdentifier = ""
    @Published var speechRate: Float = 0.5
    @Published var speechPitch: Float = 1.0
    @Published var speechVolume: Float = 1.0

    // STT 配置
    @Published var recognitionLanguage = "zh-CN"
    @Published var continuousRecognition = false

    // MARK: - Dependencies

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - 防重复触发

    private var lastWakeWordTrigger: Date = .distantPast
    private var lastCommandTrigger: Date = .distantPast
    private let wakeWordCooldown: TimeInterval = 3.0
    private let commandCooldown: TimeInterval = 1.5
    private var lastProcessedText = ""

    // MARK: - Callbacks

    var onCommand: ((VoiceCommand, String) -> Void)?
    var onWakeWord: (() -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: recognitionLanguage))
        requestPermissions()
        synthesizer.delegate = self
    }

    // MARK: - Setup

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("[VoiceService] Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("[VoiceService] Speech recognition not authorized: \(status)")
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Continuous Listening

    /// 启用后自动开始持续监听
    private func startContinuousListening() {
        guard !isListening else { return }
        startListening()
    }

    // MARK: - Speech Recognition

    func startListening() {
        guard !isListening else { return }

        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil

        // 更新识别器语言
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: recognitionLanguage))

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("[VoiceService] Speech recognizer not available")
            state = .error
            return
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // 开始识别
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = text
                    self.processRecognizedText(text, isFinal: result.isFinal)
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                DispatchQueue.main.async {
                    self.cleanupRecognition()
                    // 如果启用了持续识别，自动重新开始
                    if self.isEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.startListening()
                        }
                    }
                }
            }
        }

        // 配置音频输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            state = .listening
            print("[VoiceService] Started listening")
        } catch {
            state = .error
            print("[VoiceService] Audio engine error: \(error)")
        }
    }

    func stopListening() {
        cleanupRecognition()
        print("[VoiceService] Stopped listening")
    }

    private func cleanupRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        if state == .listening {
            state = .idle
        }
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) {
        guard isSpeechEnabled else { return }

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: text)

        // 使用配置的语音
        if !selectedVoiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: recognitionLanguage)
        }

        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        utterance.volume = speechVolume

        state = .speaking
        isSpeaking = true
        synthesizer.speak(utterance)

        print("[VoiceService] Speaking: \(text)")
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        if state == .speaking {
            state = .idle
        }
    }

    // MARK: - Command Processing

    func processCommand(_ text: String) {
        guard isEnabled else { return }

        let lowercased = text.lowercased()

        // 检查唤醒词
        if lowercased.contains(wakeWord.lowercased()) {
            triggerWakeWord()
            return
        }

        // 匹配语音命令
        if let command = VoiceCommand.match(from: text) {
            triggerCommand(command, text: text)
            return
        }

        // 未识别的命令
        speak(L10n.voiceResponseUnknown)
    }

    // MARK: - Private Methods

    private func processRecognizedText(_ text: String, isFinal: Bool) {
        guard isEnabled else { return }
        guard !text.isEmpty else { return }

        // 避免重复处理相同文本
        guard text != lastProcessedText else { return }
        lastProcessedText = text

        // 检查是否包含唤醒词
        if text.lowercased().contains(wakeWord.lowercased()) {
            triggerWakeWord()
            return
        }

        // 只在最终结果或较长文本时处理命令
        guard isFinal || text.count >= 3 else { return }

        // 检查是否是语音命令
        if let command = VoiceCommand.match(from: text) {
            triggerCommand(command, text: text)
            return
        }
    }

    /// 触发唤醒词（带冷却）
    private func triggerWakeWord() {
        let now = Date()
        guard now.timeIntervalSince(lastWakeWordTrigger) >= wakeWordCooldown else { return }
        lastWakeWordTrigger = now
        onWakeWord?()
        speak(L10n.voiceResponseHere)
    }

    /// 触发命令（带冷却）
    private func triggerCommand(_ command: VoiceCommand, text: String) {
        let now = Date()
        guard now.timeIntervalSince(lastCommandTrigger) >= commandCooldown else { return }
        lastCommandTrigger = now
        onCommand?(command, text)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            if self.state == .speaking {
                self.state = .idle
            }
        }
    }
}
