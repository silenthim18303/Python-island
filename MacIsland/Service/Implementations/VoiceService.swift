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
    @Published var isEnabled = false
    @Published var isSpeechEnabled = true
    @Published var wakeWord = "嘿，灵动岛"

    // MARK: - Dependencies

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Callbacks

    var onCommand: ((VoiceCommand, String) -> Void)?
    var onWakeWord: (() -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
        requestPermissions()
        synthesizer.delegate = self
    }

    // MARK: - Setup

    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[VoiceService] Audio session setup failed: \(error)")
        }
        #endif
    }

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

    // MARK: - Speech Recognition

    func startListening() {
        guard !isListening else { return }

        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil

        // 配置音频会话
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error
            print("[VoiceService] Audio session error: \(error)")
            return
        }
        #endif

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // 开始识别
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = text
                    self.processRecognizedText(text)
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil

                DispatchQueue.main.async {
                    self.isListening = false
                    self.state = .idle
                }
            }
        }

        // 配置音频输入
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        state = .idle
        print("[VoiceService] Stopped listening")
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) {
        guard isSpeechEnabled else { return }

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

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
        let lowercased = text.lowercased()

        // 检查唤醒词
        if lowercased.contains(wakeWord.lowercased()) {
            onWakeWord?()
            speak("我在")
            return
        }

        // 匹配语音命令
        for command in VoiceCommand.allCases {
            if lowercased.contains(command.rawValue.lowercased()) {
                onCommand?(command, text)
                return
            }
        }

        // 未识别的命令
        speak("抱歉，我没有理解您的指令")
    }

    // MARK: - Private Methods

    private func processRecognizedText(_ text: String) {
        // 检查是否包含唤醒词
        if text.lowercased().contains(wakeWord.lowercased()) {
            onWakeWord?()
            speak("我在")
            return
        }

        // 检查是否是语音命令
        for command in VoiceCommand.allCases {
            if text.lowercased().contains(command.rawValue.lowercased()) {
                onCommand?(command, text)
                return
            }
        }
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
