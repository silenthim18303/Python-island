//
//  AIChatView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - AI Chat View

struct AIChatView: View {
    @ObservedObject private var ai = AIService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider().background(Color.white.opacity(0.1))

            // 聊天区域 — 唯一可滚动的部分
            chatArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().background(Color.white.opacity(0.1))
            inputBar
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ai.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)

            Text(ai.isConnected ? L10n.enabled : L10n.disabled)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)

            if ai.isConnected && !ai.availableModels.isEmpty {
                Picker("", selection: $ai.selectedModel) {
                    ForEach(ai.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            } else if !ai.selectedModel.isEmpty {
                Text(ai.selectedModel)
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }

            Spacer()

            Button { Task { await ai.checkConnection() } } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)

            Button { ai.openServerURL() } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
            .help(L10n.aiServer)

            Button { ai.clearMessages() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Chat Area

    @ViewBuilder
    private var chatArea: some View {
        if ai.messages.isEmpty {
            emptyState
        } else {
            messageList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))

            Text(L10n.aiTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))

            if !ai.isConnected {
                Text(L10n.aiNoConfig)
                    .font(.system(size: 12))
                    .foregroundColor(.textQuaternary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.aiQuickStart)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textTertiary)
                    Text("brew install ollama && ollama pull llama3")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.textSecondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.fillSubtle))
            } else {
                Text("\(L10n.aiSend) \(ai.availableModels.count) \(L10n.aiModels)")
                    .font(.system(size: 12))
                    .foregroundColor(.textQuaternary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(ai.messages) { message in
                        messageRow(message).id(message.id)
                    }
                    if ai.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(L10n.aiThinking)
                                .font(.system(size: 11))
                                .foregroundColor(.textQuaternary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: ai.messages.count) { _, _ in
                if let last = ai.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Message Row

    private func messageRow(_ message: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            if message.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.fillSubtle))
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        message.role == .user
                            ? RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.3))
                            : RoundedRectangle(cornerRadius: 12).fill(Color.fillSubtle)
                    )

                Text(message.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.textQuaternary)
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    // MARK: - Input Bar (固定底部)

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(L10n.aiPlaceholder, text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.textPrimary)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            if ai.isGenerating {
                Button { ai.stopGeneration() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            } else {
                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .textQuaternary : Color.appAccent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.fillSubtle))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !ai.isGenerating else { return }
        inputText = ""
        Task { await ai.send(content: text) }
    }
}
