//
//  VoiceConfigView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI
import AVFoundation

/// 语音配置视图 - TTS/STT 设置
struct VoiceConfigView: View {
    @EnvironmentObject var voiceService: VoiceService
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: String = ""
    @State private var speechRate: Float = 0.5
    @State private var speechPitch: Float = 1.0
    @State private var speechVolume: Float = 1.0
    @State private var testText = "你好，我是 MacIsland 灵动岛助手"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // TTS 配置
                ttsSection

                // STT 配置
                sttSection

                // 测试区域
                testSection
            }
            .padding()
        }
        .onAppear {
            loadVoices()
        }
    }

    // MARK: - TTS Section

    private var ttsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                Text(L10n.voiceTTSConfig)
                    .font(.headline)
            }

            // 语音选择
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.voiceTTSVoice)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedVoice) {
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text(voice.name)
                            .tag(voice.identifier)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedVoice) { _, newValue in
                    voiceService.selectedVoiceIdentifier = newValue
                }
            }

            // 语速调节
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.voiceTTSSpeed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1fx", speechRate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: $speechRate, in: 0.1...1.0, step: 0.1)
                    .onChange(of: speechRate) { _, newValue in
                        voiceService.speechRate = newValue
                    }
            }

            // 音调调节
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.voiceTTSPitch)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f", speechPitch))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: $speechPitch, in: 0.5...2.0, step: 0.1)
                    .onChange(of: speechPitch) { _, newValue in
                        voiceService.speechPitch = newValue
                    }
            }

            // 音量调节
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.voiceTTSVolume)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(speechVolume * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: $speechVolume, in: 0.0...1.0, step: 0.1)
                    .onChange(of: speechVolume) { _, newValue in
                        voiceService.speechVolume = newValue
                    }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - STT Section

    private var sttSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                Text(L10n.voiceSTTConfig)
                    .font(.headline)
            }

            // 识别语言
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.voiceSTTLanguage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $voiceService.recognitionLanguage) {
                    Text("中文").tag("zh-CN")
                    Text("English").tag("en-US")
                    Text("日本語").tag("ja-JP")
                }
                .pickerStyle(.segmented)
            }

            // 唤醒词
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.voiceWakeWord)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField(L10n.voiceWakeWord, text: $voiceService.wakeWord)
                    .textFieldStyle(.roundedBorder)
            }

            // 连续识别
            Toggle(isOn: $voiceService.continuousRecognition) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.voiceSTTContinuous)
                        .font(.body)
                    Text(L10n.voiceSTTContinuousDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.purple)
                Text(L10n.voiceTest)
                    .font(.headline)
            }

            // 测试文本
            TextField(L10n.voiceTestText, text: $testText)
                .textFieldStyle(.roundedBorder)

            // 测试按钮
            Button(action: {
                voiceService.speak(testText)
            }) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text(L10n.voiceTestSpeech)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            // 当前配置摘要
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.voiceCurrentConfig)
                    .font(.caption)
                    .foregroundColor(.secondary)

                ConfigRow(label: L10n.voiceTTSVoice, value: selectedVoiceName)
                ConfigRow(label: L10n.voiceTTSSpeed, value: String(format: "%.1fx", speechRate))
                ConfigRow(label: L10n.voiceSTTLanguage, value: languageName(voiceService.recognitionLanguage))
                ConfigRow(label: L10n.voiceWakeWord, value: voiceService.wakeWord)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Helpers

    private var selectedVoiceName: String {
        availableVoices.first { $0.identifier == selectedVoice }?.name ?? "系统默认"
    }

    private func languageName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文"
        case "en-US": return "English"
        case "ja-JP": return "日本語"
        default: return code
        }
    }

    private func loadVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") || $0.language.hasPrefix("ja") }
            .sorted { $0.name < $1.name }

        selectedVoice = voiceService.selectedVoiceIdentifier.isEmpty
            ? (AVSpeechSynthesisVoice(language: "zh-CN")?.identifier ?? "")
            : voiceService.selectedVoiceIdentifier
    }
}

// MARK: - Config Row

private struct ConfigRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}
