//
//  VoiceSettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import SwiftUI

/// 语音设置页面
struct VoiceSettingsView: View {
    @EnvironmentObject var voiceService: VoiceService
    @State private var showCommandList = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 语音控制开关
                voiceControlSection

                // 语音播报开关
                voiceSpeechSection

                // 语音配置
                voiceConfigSection

                // 唤醒词设置
                wakeWordSection

                // 语音命令列表
                commandListSection

                // 测试区域
                testSection
            }
            .padding()
        }
    }

    // MARK: - Voice Config Section

    private var voiceConfigSection: some View {
        NavigationLink(destination: VoiceConfigView()) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.gray)
                Text(L10n.voiceAdvancedConfig)
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice Control Section

    private var voiceControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                Text(L10n.voiceControl)
                    .font(.headline)
            }

            Toggle(isOn: $voiceService.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.voiceEnableControl)
                        .font(.body)
                    Text(L10n.voiceEnableControlDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if voiceService.isEnabled {
                HStack {
                    Image(systemName: voiceService.state.systemImage)
                        .foregroundColor(voiceService.state == .listening ? .green : .secondary)
                    Text(voiceService.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Voice Speech Section

    private var voiceSpeechSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                Text(L10n.voiceSpeech)
                    .font(.headline)
            }

            Toggle(isOn: $voiceService.isSpeechEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.voiceEnableSpeech)
                        .font(.body)
                    Text(L10n.voiceEnableSpeechDesc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Wake Word Section

    private var wakeWordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wake")
                    .foregroundColor(.purple)
                Text(L10n.voiceWakeWord)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.voiceCurrentWakeWord)
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField(L10n.voiceWakeWord, text: $voiceService.wakeWord)
                    .textFieldStyle(.roundedBorder)

                Text(L10n.voiceWakeWordHint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Command List Section

    private var commandListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.green)
                Text(L10n.voiceCommands)
                    .font(.headline)
                Spacer()
                Button(L10n.voiceViewAll) {
                    showCommandList = true
                }
                .font(.caption)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 8) {
                ForEach(VoiceCommand.allCases.prefix(6), id: \.self) { command in
                    CommandBadge(command: command)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .sheet(isPresented: $showCommandList) {
            CommandListView()
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.red)
                Text(L10n.voiceTest)
                    .font(.headline)
            }

            VStack(spacing: 12) {
                // 语音输入测试
                Button(action: {
                    if voiceService.isListening {
                        voiceService.stopListening()
                    } else {
                        voiceService.startListening()
                    }
                }) {
                    HStack {
                        Image(systemName: voiceService.isListening ? "stop.fill" : "mic.fill")
                        Text(voiceService.isListening ? L10n.voiceStopListening : L10n.voiceStartListening)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(voiceService.isListening ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // 识别结果
                if !voiceService.recognizedText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.voiceRecognitionResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(voiceService.recognizedText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(8)
                    }
                }

                // 语音播报测试
                Button(action: {
                    voiceService.speak(L10n.voiceTestText)
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text(L10n.voiceTestSpeech)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// MARK: - Command Badge

private struct CommandBadge: View {
    let command: VoiceCommand

    var body: some View {
        VStack(spacing: 4) {
            Text(command.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
            Text(command.description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
    }
}

// MARK: - Command List View

private struct CommandListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(VoiceCommand.allCases, id: \.self) { command in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(command.displayName)
                            .font(.headline)
                        Text(command.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("「\(command.rawValue)」")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(L10n.voiceCommands)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.voiceDone) {
                        dismiss()
                    }
                }
            }
        }
    }
}
