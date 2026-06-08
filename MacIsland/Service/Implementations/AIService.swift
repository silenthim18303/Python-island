//
//  AIService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation
import Combine
import Security
import AppKit

// MARK: - Keychain Helper

private enum AIKeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Chat Message

struct AIMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - API Models

private struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]
}

private struct OllamaModel: Decodable {
    let name: String
}

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

private struct OpenAIModel: Decodable {
    let id: String
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenAIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let role: String
        let content: String
    }
}

// MARK: - AI Service

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    @Published var messages: [AIMessage] = []
    @Published var isGenerating = false
    @Published var availableModels: [String] = []
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "aiSelectedModel") }
    }
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "aiServerURL") }
    }
    @Published var apiKey: String {
        didSet { AIKeychainHelper.save(key: "aiAPIKey", value: apiKey) }
    }
    @Published var isConnected = false

    private var currentTask: Task<Void, Never>?
    private var currentGenerationID: UUID?

    private init() {
        self.serverURL = UserDefaults.standard.string(forKey: "aiServerURL") ?? "http://localhost:11434"
        self.selectedModel = UserDefaults.standard.string(forKey: "aiSelectedModel") ?? ""
        self.apiKey = AIKeychainHelper.load(key: "aiAPIKey") ?? ""
    }

    // MARK: - Public

    func checkConnection() async {
        // 1. 先用当前配置检测
        if await tryOllamaConnect() { return }
        if !apiKey.isEmpty {
            if await tryOpenAIConnect() { return }
            if await tryOpenAIChatTest() { return }
        }

        // 2. 自动探测常见端口
        let commonPorts = [11434, 8080, 3000, 5000, 5001, 1234, 4000, 8000, 9000]
        for port in commonPorts {
            for scheme in ["http", "https"] {
                let candidate = "\(scheme)://localhost:\(port)"
                if candidate == serverURL { continue }
                serverURL = candidate
                if await tryOllamaConnect() { return }
                if !apiKey.isEmpty {
                    if await tryOpenAIConnect() { return }
                    if await tryOpenAIChatTest() { return }
                }
            }
        }

        // 3. 尝试当前 URL 的 http/https 切换
        let host = serverURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "/", with: "")
        for scheme in ["http", "https"] {
            let candidate = "\(scheme)://\(host)"
            if candidate == serverURL { continue }
            serverURL = candidate
            if await tryOllamaConnect() { return }
            if !apiKey.isEmpty {
                if await tryOpenAIConnect() { return }
                if await tryOpenAIChatTest() { return }
            }
        }

        isConnected = false
        availableModels = []
    }

    func send(content: String) async {
        guard !isGenerating else { return }

        let generationID = UUID()
        currentGenerationID = generationID

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performGeneration(content: content, generationID: generationID)
        }
        currentTask = task
        await task.value
    }

    private func performGeneration(content: String, generationID: UUID) async {
        let userMessage = AIMessage(role: .user, content: content)
        messages.append(userMessage)

        isGenerating = true
        defer {
            if currentGenerationID == generationID {
                currentTask = nil
                currentGenerationID = nil
                isGenerating = false
            }
        }

        if apiKey.isEmpty {
            await sendOllama(content: content)
        } else {
            await sendOpenAI(content: content)
        }
    }

    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        currentGenerationID = nil
        isGenerating = false
    }

    func clearMessages() {
        messages.removeAll()
    }

    func openServerURL() {
        guard let url = URL(string: serverURL) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Ollama Detection

    private func tryOllamaConnect() async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/tags") else { return false }
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            availableModels = response.models.map { $0.name }
            isConnected = true
            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - OpenAI Detection

    private func tryOpenAIConnect() async -> Bool {
        guard let url = URL(string: "\(serverURL)/v1/models") else { return false }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            // 兼容多种响应格式
            if let modelsResponse = try? JSONDecoder().decode(OpenAIModelsResponse.self, from: data) {
                availableModels = modelsResponse.data.map { $0.id }
            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["data"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["id"] as? String }
            } else {
                // 有些 API 返回简单数组或其他格式
                availableModels = []
            }
            isConnected = true
            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - Fallback: Send Test Chat

    /// 当 /v1/models 不可用时，用一条测试消息验证 API 是否可用
    private func tryOpenAIChatTest() async -> Bool {
        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else { return false }
        let testBody: [String: Any] = [
            "model": selectedModel.isEmpty ? "gpt-3.5-turbo" : selectedModel,
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1,
        ]
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config)

        do {
            let (_, response) = try await session.data(for: urlRequest)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isConnected = true
                availableModels = selectedModel.isEmpty ? [] : [selectedModel]
                return true
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Send via Ollama

    private func sendOllama(content: String) async {
        let history = messages.map { msg in
            OpenAIChatRequest.Message(role: msg.role.rawValue, content: msg.content)
        }

        let systemMessage = OpenAIChatRequest.Message(
            role: "system",
            content: L10n.aiSystemPrompt
        )

        let body: [String: Any] = [
            "model": selectedModel,
            "messages": ([systemMessage] + history).map { ["role": $0.role, "content": $0.content] },
            "stream": false,
        ]

        guard let url = URL(string: "\(serverURL)/api/chat") else { return }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 120

        do {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            guard !Task.isCancelled else { return }

            // Ollama 返回格式: {"message": {"role": "...", "content": "..."}}
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                messages.append(AIMessage(role: .assistant, content: content))
            }
        } catch {
            guard !Self.isCancellationError(error) else { return }
            messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIConnection): \(error.localizedDescription)\n\n\(L10n.aiServer) (\(serverURL))"))
        }
    }

    // MARK: - Send via OpenAI

    private func sendOpenAI(content: String) async {
        let history = messages.map { msg in
            OpenAIChatRequest.Message(role: msg.role.rawValue, content: msg.content)
        }

        let systemMessage = OpenAIChatRequest.Message(
            role: "system",
            content: L10n.aiSystemPrompt
        )

        let request = OpenAIChatRequest(
            model: selectedModel,
            messages: [systemMessage] + history
        )

        guard let url = URL(string: "\(serverURL)/v1/chat/completions") else { return }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 120

        do {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            guard !Task.isCancelled else { return }

            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            if let content = response.choices.first?.message.content {
                messages.append(AIMessage(role: .assistant, content: content))
            }
        } catch {
            guard !Self.isCancellationError(error) else { return }
            messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIRequest): \(error.localizedDescription)"))
        }
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
