//
//  AIVoiceChatView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import SwiftUI

/// AI 语音对话视图
struct AIVoiceChatView: View {
    @EnvironmentObject var voiceService: VoiceService
    @StateObject private var localAI = LocalAIService.shared
    @State private var chatMessages: [ChatMessage] = []
    @State private var isProcessing = false
    @State private var inputText = ""
    @State private var showTextInput = false

    struct ChatMessage: Identifiable {
        let id = UUID()
        let content: String
        let isUser: Bool
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 对话列表
            chatListView

            // 输入区域
            inputView
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 18))
                .foregroundColor(.purple)

            Text(L10n.aiVoiceChatTitle)
                .font(.headline)

            Spacer()

            // 状态指示
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Chat List

    private var chatListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chatMessages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(chatMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }

                    if isProcessing {
                        typingIndicator
                    }
                }
                .padding()
            }
            .onChange(of: chatMessages.count) { _, _ in
                if let lastMessage = chatMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isUser ? Color.purple : Color(nsColor: .controlBackgroundColor))
                    )

                Text(timeString(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser { Spacer() }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.purple.opacity(0.5))

            Text(L10n.aiVoiceChatEmpty)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(L10n.aiVoiceChatHint)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .opacity(0.5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            Spacer()
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 8) {
            Divider()

            // 语音按钮
            HStack(spacing: 16) {
                // 语音输入按钮
                Button(action: {
                    toggleVoiceInput()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: voiceService.isListening ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(voiceService.isListening ? .red : .purple)
                            .symbolEffect(.pulse, isActive: voiceService.isListening)

                        Text(voiceService.isListening ? L10n.aiVoiceChatStop : L10n.aiVoiceChatSpeak)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                // 文本输入按钮
                Button(action: {
                    showTextInput.toggle()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)

                        Text(L10n.aiVoiceChatType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                // 清除对话
                Button(action: {
                    chatMessages.removeAll()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.7))

                        Text(L10n.aiVoiceChatClear)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)

            // 文本输入框
            if showTextInput {
                HStack {
                    TextField(L10n.aiVoiceChatPlaceholder, text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage(inputText)
                            inputText = ""
                        }

                    Button(action: {
                        sendMessage(inputText)
                        inputText = ""
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if isProcessing { return .orange }
        if voiceService.isListening { return .green }
        return .secondary
    }

    private var statusText: String {
        if isProcessing { return L10n.aiVoiceChatThinking }
        if voiceService.isListening { return L10n.aiVoiceChatListening }
        return L10n.aiVoiceChatReady
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func toggleVoiceInput() {
        if voiceService.isListening {
            voiceService.stopListening()
            if !voiceService.recognizedText.isEmpty {
                sendMessage(voiceService.recognizedText)
            }
        } else {
            voiceService.startListening()
        }
    }

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 添加用户消息
        let userMessage = ChatMessage(content: trimmed, isUser: true, timestamp: Date())
        chatMessages.append(userMessage)

        // 发送到本地 AI
        isProcessing = true

        Task {
            let response = await localAI.process(trimmed)

            await MainActor.run {
                isProcessing = false

                let aiMessage = ChatMessage(content: response, isUser: false, timestamp: Date())
                chatMessages.append(aiMessage)

                // 语音播报回复
                if voiceService.isSpeechEnabled {
                    voiceService.speak(response)
                }
            }
        }
    }
}
