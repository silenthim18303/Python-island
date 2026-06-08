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

    // MARK: - Voice Control Section

    private var voiceControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                Text("语音控制")
                    .font(.headline)
            }

            Toggle(isOn: $voiceService.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("启用语音控制")
                        .font(.body)
                    Text("使用语音指令控制灵动岛")
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
                Text("语音播报")
                    .font(.headline)
            }

            Toggle(isOn: $voiceService.isSpeechEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("启用语音播报")
                        .font(.body)
                    Text("播报天气、计时器、通知等信息")
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
                Text("唤醒词")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("当前唤醒词")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("唤醒词", text: $voiceService.wakeWord)
                    .textFieldStyle(.roundedBorder)

                Text("说出唤醒词后，再说出指令。例如：「嘿，灵动岛，播放音乐」")
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
                Text("语音指令")
                    .font(.headline)
                Spacer()
                Button("查看全部") {
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
                Text("测试")
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
                        Text(voiceService.isListening ? "停止监听" : "开始监听")
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
                        Text("识别结果")
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
                    voiceService.speak("你好，我是 MacIsland 灵动岛助手")
                }) {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("测试语音播报")
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
            .navigationTitle("语音指令")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
