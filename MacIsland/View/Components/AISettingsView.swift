//
//  AISettingsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

/// AI 设置页面 — 原生偏好设置窗口中的 AI 配置
struct AISettingsView: View {
    @ObservedObject private var ai = AIService.shared
    @EnvironmentObject var voiceService: VoiceService
    @State private var selectedProvider: AIProvider = AIProviders.all[0]

    var body: some View {
        Form {
            // AI 服务配置
            Section(L10n.aiSettings) {
                // 服务商选择
                Picker("服务商", selection: $selectedProvider) {
                    ForEach(AIProviders.all) { provider in
                        Text(provider.name).tag(provider)
                    }
                }
                .onChange(of: selectedProvider) { _, provider in
                    if !provider.isCustom {
                        ai.serverURL = provider.url
                    }
                }

                // 服务地址
                if selectedProvider.isCustom {
                    HStack {
                        TextField("http://localhost:11434", text: $ai.serverURL)
                            .textFieldStyle(.roundedBorder)
                        Button(L10n.voiceTest) {
                            Task { await ai.checkConnection() }
                        }
                        .controlSize(.small)
                    }
                } else {
                    HStack {
                        Text(ai.serverURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(L10n.voiceTest) {
                            Task { await ai.checkConnection() }
                        }
                        .controlSize(.small)
                    }
                }

                SecureField(L10n.aiApiKey, text: $ai.apiKey)

                Picker(L10n.aiModelName, selection: $ai.selectedModel) {
                    Text(L10n.aiModels).tag("")
                    ForEach(ai.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }

                HStack {
                    Circle()
                        .fill(ai.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(ai.isConnected ? "已连接" : "未连接")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if ai.isConnected && !ai.availableModels.isEmpty {
                        Text("\(ai.availableModels.count) \(L10n.aiModels)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // TTS 配置
            Section(L10n.aiTTS) {
                NavigationLink(L10n.voiceTTSConfig) {
                    VoiceConfigView()
                }
            }

            // STT 配置
            Section(L10n.aiSTT) {
                NavigationLink(L10n.voiceSTTConfig) {
                    VoiceConfigView()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if let matched = AIProviders.match(url: ai.serverURL) {
                selectedProvider = matched
            } else {
                selectedProvider = AIProviders.all[0]
            }
        }
    }
}
