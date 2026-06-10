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

// MARK: - Anthropic API Models

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [Message]
    let system: String?

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]?

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

// MARK: - AI Provider Presets

struct AIProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let needsKey: Bool

    /// 是否为自定义配置（URL 可编辑）
    var isCustom: Bool { url.isEmpty }
}

enum AIProviders {
    static let all: [AIProvider] = [
        AIProvider(id: "custom",     name: "自定义配置",                        url: "",                                  needsKey: false),
        AIProvider(id: "openai",     name: "OpenAI Official",                  url: "https://api.openai.com/v1",         needsKey: true),
        AIProvider(id: "deepseek",   name: "DeepSeek",                         url: "https://api.deepseek.com/v1",       needsKey: true),
        AIProvider(id: "mimo",       name: "Xiaomi MiMo",                      url: "https://api.xiaomimimo.com/v1",     needsKey: true),
        AIProvider(id: "siliconflow",name: "SiliconFlow (硅基流动)",             url: "https://api.siliconflow.cn/v1",     needsKey: true),
        AIProvider(id: "openrouter", name: "OpenRouter",                       url: "https://openrouter.ai/api/v1",      needsKey: true),
        AIProvider(id: "zhipu",      name: "Zhipu GLM (智谱)",                  url: "https://open.bigmodel.cn/api/paas/v4", needsKey: true),
        AIProvider(id: "moonshot",   name: "Kimi (月之暗面)",                    url: "https://api.moonshot.cn/v1",        needsKey: true),
        AIProvider(id: "stepfun",    name: "StepFun (阶跃星辰)",                url: "https://api.stepfun.com/v1",        needsKey: true),
        AIProvider(id: "bailian",    name: "Bailian (阿里云百炼)",               url: "https://dashscope.aliyuncs.com/compatible-mode/v1", needsKey: true),
        AIProvider(id: "baidu",      name: "Baidu Qianfan (百度千帆)",           url: "https://qianfan.baidubce.com/v2",   needsKey: true),
        AIProvider(id: "minimax",    name: "MiniMax",                          url: "https://api.minimaxi.com/v1",       needsKey: true),
        AIProvider(id: "anthropic",  name: "Anthropic (Claude)",               url: "https://api.anthropic.com",         needsKey: true),
        AIProvider(id: "ollama",     name: "Ollama (本地)",                     url: "http://localhost:11434",            needsKey: false),
        AIProvider(id: "azure",      name: "Azure OpenAI",                     url: "https://{resource}.openai.azure.com", needsKey: true),
        AIProvider(id: "volc",       name: "火山 Agentplan (火山引擎)",          url: "https://open.volcengineapi.com",    needsKey: true),
    ]

    /// 根据当前 URL 匹配 provider
    static func match(url: String) -> AIProvider? {
        let normalized = AIService.normalizeURL(url)
        return all.first { provider in
            !provider.isCustom && normalized.contains(provider.url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").components(separatedBy: "/").first ?? "")
        }
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
        didSet {
            // 只在值实际变化时保存，避免递归
            UserDefaults.standard.set(serverURL, forKey: "aiServerURL")
        }
    }
    @Published var apiKey: String {
        didSet { AIKeychainHelper.save(key: "aiAPIKey", value: apiKey) }
    }
    @Published var isConnected = false

    private var currentTask: Task<Void, Never>?
    private var currentGenerationID: UUID?

    private init() {
        let saved = UserDefaults.standard.string(forKey: "aiServerURL") ?? "http://localhost:11434"
        self.serverURL = Self.normalizeURL(saved)
        self.selectedModel = UserDefaults.standard.string(forKey: "aiSelectedModel") ?? ""
        self.apiKey = AIKeychainHelper.load(key: "aiAPIKey") ?? ""
    }

    /// 标准化服务地址：补全协议、去空格、去尾斜杠
    static func normalizeURL(_ input: String) -> String {
        var url = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉尾部斜杠
        while url.hasSuffix("/") { url = String(url.dropLast()) }
        // 空输入返回默认
        guard !url.isEmpty else { return "http://localhost:11434" }
        // 已有协议 → 原样返回
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
        // 纯数字和点 → IP 地址
        if url.range(of: #"^\d+\.\d+\.\d+\.\d+"#, options: .regularExpression) != nil {
            return "http://\(url)"
        }
        // 含冒号（如 localhost:8080, mimo:3000）
        if url.contains(":") {
            return "http://\(url)"
        }
        // 含有点号且有路径（如 api.deepseek.com/v1, xxx.com/anthropic）→ 加 https
        if url.contains(".") && url.contains("/") {
            return "https://\(url)"
        }
        // 含有点号无路径（如 api.deepseek.com）→ 加 https 和 /v1
        if url.contains(".") {
            return "https://\(url)/v1"
        }
        // 纯主机名（如 mimo, localhost, ollama）→ 本地服务
        return "http://\(url):11434"
    }

    // MARK: - Public

    func checkConnection() async {
        // 标准化当前地址
        let normalized = Self.normalizeURL(serverURL)
        if normalized != serverURL { serverURL = normalized }

        // 1. 先用当前配置检测
        if await tryConnect(url: serverURL) { return }

        // 2. 尝试 http/https 切换
        let host = serverURL
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "/", with: "")
        for scheme in ["http", "https"] {
            let candidate = "\(scheme)://\(host)"
            if candidate == serverURL { continue }
            if await tryConnect(url: candidate) {
                serverURL = candidate
                return
            }
        }

        // 3. 自动探测常见端口（仅 localhost）
        if host.hasPrefix("localhost") || host.hasPrefix("127.0.0.1") {
            for port in [11434, 8080, 3000, 5000, 5001, 1234, 4000, 8000, 9000] {
                for scheme in ["http", "https"] {
                    let candidate = "\(scheme)://localhost:\(port)"
                    if candidate == serverURL { continue }
                    if await tryConnect(url: candidate) {
                        serverURL = candidate
                        return
                    }
                }
            }
        }

        isConnected = false
        availableModels = []
    }

    /// 尝试连接指定 URL（Ollama + OpenAI + Anthropic）
    private func tryConnect(url: String) async -> Bool {
        // 1. Ollama 本地检测
        if await tryOllamaConnect(url: url) { return true }

        // 2. 根据端点类型选择协议
        let endpointType = detectEndpointType(url)
        switch endpointType {
        case .anthropic:
            // 原生 Anthropic (api.anthropic.com)
            if !apiKey.isEmpty, await tryAnthropicConnect(url: url) { return true }
        case .anthropicProxy:
            // Anthropic 代理端点（如 xiaomimimo.com/anthropic）：先试 OpenAI，再试 Anthropic
            if await tryOpenAIConnect(url: url) { return true }
            if !apiKey.isEmpty {
                if await tryOpenAIChatTest(url: url) { return true }
                if await tryAnthropicConnect(url: url) { return true }
            }
        case .openai:
            if await tryOpenAIConnect(url: url) { return true }
            if !apiKey.isEmpty, await tryOpenAIChatTest(url: url) { return true }
        case .unknown:
            if await tryOpenAIConnect(url: url) { return true }
            if !apiKey.isEmpty {
                if await tryOpenAIChatTest(url: url) { return true }
                if await tryAnthropicConnect(url: url) { return true }
            }
        }
        return false
    }

    /// 端点协议类型
    private enum EndpointType { case openai, anthropic, anthropicProxy, unknown }

    /// 根据 URL 路径检测端点协议类型
    private func detectEndpointType(_ url: String? = nil) -> EndpointType {
        let target = (url ?? serverURL).lowercased()
        // api.anthropic.com → 原生 Anthropic
        if target.contains("api.anthropic.com") { return .anthropic }
        // 路径含 /anthropic（非 api.anthropic.com）→ 代理端点，优先 OpenAI
        if target.contains("/anthropic") { return .anthropicProxy }
        // 路径含 /v1 → OpenAI
        if target.contains("/v1") { return .openai }
        // 本地地址 → OpenAI (Ollama)
        if target.contains("localhost") || target.contains("127.0.0.1") { return .openai }
        // 其他含 anthropic/claude → 代理端点
        if target.contains("anthropic") || target.contains("claude") { return .anthropicProxy }
        return .unknown
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

        // 带 Agent 工具信息的系统提示
        await sendWithAgent(content: content)
    }

    /// 带 Agent 工具调用的发送
    private func sendWithAgent(content: String) async {
        // 构建带工具信息的消息
        let agentTools = AIAgent.shared.tools
        let toolsDesc = agentTools.map { tool in
            "- \(tool.name): \(tool.description)"
        }.joined(separator: "\n")

        let agentSystemPrompt = """
        \(L10n.aiSystemPrompt)

        你可以使用以下工具来帮助用户。当你需要使用工具时，请用以下格式回复：
        [TOOL_CALL]name=工具名 参数名=参数值[/TOOL_CALL]

        可用工具：
        \(toolsDesc)

        注意：
        1. 只有当用户请求需要工具时才使用工具
        2. 可以连续调用多个工具
        3. 工具调用后等待结果再回复用户
        """

        // 发送请求
        let endpointType = detectEndpointType()
        var response = ""

        switch endpointType {
        case .anthropic:
            response = await sendAnthropicWithTools(content: content, systemPrompt: agentSystemPrompt)
        case .anthropicProxy:
            response = await sendOpenAIWithTools(content: content, systemPrompt: agentSystemPrompt)
        case .openai:
            let isLocal = serverURL.contains("localhost") || serverURL.contains("127.0.0.1")
            let useOllama = isLocal ? await isOllamaAvailable() : false
            if useOllama {
                response = await sendOllamaWithTools(content: content, systemPrompt: agentSystemPrompt)
            } else {
                response = await sendOpenAIWithTools(content: content, systemPrompt: agentSystemPrompt)
            }
        case .unknown:
            if !apiKey.isEmpty {
                response = await sendAnthropicWithTools(content: content, systemPrompt: agentSystemPrompt)
            } else {
                response = await sendOpenAIWithTools(content: content, systemPrompt: agentSystemPrompt)
            }
        }

        guard !Task.isCancelled else { return }

        // 检查是否有工具调用
        let toolCalls = AIAgent.shared.extractToolCalls(from: response)

        if toolCalls.isEmpty {
            // 无工具调用，直接显示回复
            if !response.isEmpty {
                messages.append(AIMessage(role: .assistant, content: response))
            }
        } else {
            // 执行工具调用
            var toolResults: [String] = []
            for toolCall in toolCalls {
                let result = await AIAgent.shared.execute(toolCall: toolCall)
                let status = result.success ? "✅" : "❌"
                toolResults.append("\(status) \(result.toolName): \(result.result)")
            }

            // 将工具结果发送给 AI 获取最终回复
            let toolResultText = toolResults.joined(separator: "\n")
            let followUp = "工具执行结果:\n\(toolResultText)\n\n请根据以上结果回复用户。"

            // 递归调用（限制最多 3 轮工具调用）
            let currentDepth = messages.filter { $0.content.contains("[TOOL_CALL]") }.count
            if currentDepth < 3 {
                await sendWithAgent(content: followUp)
            } else {
                messages.append(AIMessage(role: .assistant, content: toolResultText))
            }
        }
    }

    /// 检测 Ollama 是否可用（不修改状态）
    private func isOllamaAvailable() async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/tags") else { return false }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: config)
        guard let (data, response) = try? await session.data(from: url),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return false
        }
        return (try? JSONDecoder().decode(OllamaModelsResponse.self, from: data)) != nil
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

    private func tryOllamaConnect(url: String? = nil) async -> Bool {
        let baseURL = url ?? serverURL
        guard let connectURL = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: connectURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return false
            }
            if let resp = try? JSONDecoder().decode(OllamaModelsResponse.self, from: data) {
                availableModels = resp.models.map { $0.name }
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["name"] as? String }
            } else {
                return false
            }
            isConnected = true
            if url != nil { serverURL = baseURL }
            if selectedModel.isEmpty, let first = availableModels.first {
                selectedModel = first
            }
            return true
        } catch {
            return false
        }
    }

    // MARK: - OpenAI Detection

    private func tryOpenAIConnect(url: String? = nil) async -> Bool {
        let baseURL = url ?? serverURL
        // 去掉尾部 /v1 避免重复
        let cleanBase = baseURL.replacingOccurrences(of: "/v1$", with: "", options: .regularExpression)

        // 尝试多个模型列表端点
        let modelEndpoints = [
            "\(cleanBase)/v1/models",
            "\(cleanBase)/models",
        ]

        for endpoint in modelEndpoints {
            guard let connectURL = URL(string: endpoint) else { continue }
            var urlRequest = URLRequest(url: connectURL)
            if !apiKey.isEmpty {
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)

            if let (data, response) = try? await session.data(for: urlRequest),
               let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                let models = parseModelList(data)
                isConnected = true
                if url != nil { serverURL = baseURL }
                if !models.isEmpty {
                    availableModels = models
                }
                if selectedModel.isEmpty, let first = availableModels.first {
                    selectedModel = first
                }
                return true
            }
        }

        return false
    }

    /// 兼容多种模型列表格式
    private func parseModelList(_ data: Data) -> [String] {
        // 1. OpenAI 标准格式: {"data": [{"id": "model-name"}]}
        if let resp = try? JSONDecoder().decode(OpenAIModelsResponse.self, from: data) {
            return resp.data.map { $0.id }
        }
        // 2. JSON 手动解析（兼容更多字段名）
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // {"data": [{"id": "..."}]}
            if let models = json["data"] as? [[String: Any]] {
                let ids = models.compactMap { $0["id"] as? String }
                if !ids.isEmpty { return ids }
            }
            // {"models": [{"name": "..."}]} — Ollama 格式
            if let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                if !names.isEmpty { return names }
            }
            // {"models": ["model1", "model2"]} — 简单数组
            if let models = json["models"] as? [String] {
                return models
            }
        }
        // 3. 纯数组: ["model1", "model2"]
        if let models = try? JSONDecoder().decode([String].self, from: data) {
            return models
        }
        return []
    }

    // MARK: - Fallback: Send Test Chat

    /// 当 /v1/models 不可用时，用一条测试消息验证 API 是否可用
    private func tryOpenAIChatTest(url: String? = nil) async -> Bool {
        let baseURL = url ?? serverURL
        let cleanBase = baseURL.replacingOccurrences(of: "/v1$", with: "", options: .regularExpression)

        // 尝试多个可能的端点
        let endpoints = [
            "\(cleanBase)/v1/chat/completions",
            "\(cleanBase)/chat/completions",
        ]

        for endpoint in endpoints {
            guard let testURL = URL(string: endpoint) else { continue }
            let testBody: [String: Any] = [
                "model": selectedModel.isEmpty ? "gpt-3.5-turbo" : selectedModel,
                "messages": [["role": "user", "content": "hi"]],
                "max_tokens": 1,
            ]
            var urlRequest = URLRequest(url: testURL)
            urlRequest.httpMethod = "POST"
            if !apiKey.isEmpty {
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            let session = URLSession(configuration: config)

            do {
                let (data, response) = try await session.data(for: urlRequest)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    // 尝试解析响应获取模型列表
                    let models = parseModelList(data)
                    isConnected = true
                    if url != nil { serverURL = baseURL }
                    if !models.isEmpty {
                        availableModels = models
                    } else {
                        availableModels = selectedModel.isEmpty ? [] : [selectedModel]
                    }
                    return true
                }
            } catch {
                continue
            }
        }
        return false
    }

    // MARK: - Anthropic Detection

    private func tryAnthropicConnect(url: String) async -> Bool {
        let endpoints = buildAnthropicEndpoints(url)
        // 尝试多个可能的模型名
        let testModels = [
            selectedModel.isEmpty ? nil : selectedModel,
            "claude-sonnet-4-20250514",
            "anthropic.claude-3-5-sonnet-20241022-v2:0",
            "claude-3-5-sonnet-20241022",
            "claude-3-haiku-20240307",
        ].compactMap { $0 }

        for endpoint in endpoints {
            guard let connectURL = URL(string: endpoint) else { continue }

            for model in testModels {
                let testBody: [String: Any] = [
                    "model": model,
                    "max_tokens": 1,
                    "messages": [["role": "user", "content": "hi"]],
                ]
                var urlRequest = URLRequest(url: connectURL)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: testBody)
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 8
                let session = URLSession(configuration: config)

                guard let (data, response) = try? await session.data(for: urlRequest),
                      let httpResponse = response as? HTTPURLResponse else { continue }

                // 2xx → 连接成功
                if (200...299).contains(httpResponse.statusCode) {
                    isConnected = true
                    serverURL = url
                    selectedModel = model
                    // 尝试获取更多模型
                    _ = try? await fetchAnthropicModels(url: url)
                    return true
                }

                // 401 → API Key 无效，不需要继续尝试其他模型
                if httpResponse.statusCode == 401 {
                    let errorMsg = parseHTTPError(data: data, statusCode: 401)
                    print("[AI] Anthropic auth failed: \(errorMsg)")
                    return false
                }

                // 400 且包含 "Not supported model" → 尝试下一个模型
                // 其他错误 → 尝试下一个端点
            }
        }
        return false
    }

    /// 尝试获取 Anthropic 模型列表
    private func fetchAnthropicModels(url: String) async -> [String] {
        let base = url
            .replacingOccurrences(of: "/v1/messages$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "/v1$", with: "", options: .regularExpression)
        let endpoints = ["\(base)/v1/models", "\(base)/models"]

        for endpoint in endpoints {
            guard let modelURL = URL(string: endpoint) else { continue }
            var request = URLRequest(url: modelURL)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5
            let session = URLSession(configuration: config)

            if let (data, response) = try? await session.data(for: request),
               let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                let models = parseModelList(data)
                if !models.isEmpty {
                    availableModels = models
                    return models
                }
            }
        }
        return []
    }

    // MARK: - Send via Anthropic

    private func sendAnthropic(content: String) async {
        let history = messages.map { msg in
            AnthropicRequest.Message(role: msg.role.rawValue, content: msg.content)
        }

        let endpoints = buildAnthropicEndpoints(serverURL)

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }

            let request = AnthropicRequest(
                model: selectedModel,
                max_tokens: 4096,
                messages: history,
                system: L10n.aiSystemPrompt
            )

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            do {
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                guard !Task.isCancelled else { return }

                if let httpResponse = response as? HTTPURLResponse {
                    if !(200...299).contains(httpResponse.statusCode) {
                        if httpResponse.statusCode == 404 || httpResponse.statusCode == 405 {
                            continue
                        }
                        let errorMsg = parseHTTPError(data: data, statusCode: httpResponse.statusCode)
                        messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIRequest): \(errorMsg)"))
                        return
                    }
                }

                if let text = extractAnthropicContent(from: data) {
                    messages.append(AIMessage(role: .assistant, content: text))
                    return
                }
            } catch {
                if Self.isCancellationError(error) { return }
                continue
            }
        }

        messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIRequest): Anthropic 所有端点均无法连接 (\(serverURL))"))
    }

    /// 构建多个可能的 Anthropic 端点 URL
    private func buildAnthropicEndpoints(_ baseURL: String) -> [String] {
        // 去掉尾部 /v1, /messages, /v1/messages
        var base = baseURL
            .replacingOccurrences(of: "/v1/messages$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "/v1$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "/messages$", with: "", options: .regularExpression)

        return [
            "\(base)/v1/messages",
            "\(base)/messages",
        ]
    }

    /// 构建多个可能的 OpenAI 端点 URL
    private func buildOpenAIEndpoints(_ baseURL: String) -> [String] {
        // 去掉尾部 /v1
        let base = baseURL.replacingOccurrences(of: "/v1$", with: "", options: .regularExpression)

        return [
            "\(base)/v1/chat/completions",
            "\(base)/chat/completions",
        ]
    }

    /// 解析 Anthropic 响应
    private func extractAnthropicContent(from data: Data) -> String? {
        // 标准格式: {"content": [{"type": "text", "text": "..."}]}
        if let resp = try? JSONDecoder().decode(AnthropicResponse.self, from: data) {
            let texts = resp.content?.compactMap { $0.text } ?? []
            let joined = texts.joined()
            if !joined.isEmpty { return joined }
        }
        // 手动解析
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let content = json["content"] as? [[String: Any]] {
                let texts = content.compactMap { $0["text"] as? String }
                let joined = texts.joined()
                if !joined.isEmpty { return joined }
            }
            // 错误响应
            if let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                return "Anthropic 错误: \(msg)"
            }
        }
        return nil
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
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard !Task.isCancelled else { return }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let errorMsg = parseHTTPError(data: data, statusCode: httpResponse.statusCode)
                messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIConnection): \(errorMsg)"))
                return
            }

            if let text = extractContent(from: data) {
                messages.append(AIMessage(role: .assistant, content: text))
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "非文本响应(\(data.count) bytes)"
                let preview = raw.count > 200 ? String(raw.prefix(200)) + "..." : raw
                messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIConnection): 未知响应格式\n\n\(preview)"))
            }
        } catch {
            guard !Self.isCancellationError(error) else { return }
            messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIConnection): \(error.localizedDescription)"))
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

        // 构建端点列表
        let endpoints = buildOpenAIEndpoints(serverURL)

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            if !apiKey.isEmpty {
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            do {
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                guard !Task.isCancelled else { return }

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    // 404 继续尝试下一个端点
                    if httpResponse.statusCode == 404 { continue }
                    let errorMsg = parseHTTPError(data: data, statusCode: httpResponse.statusCode)
                    messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIRequest): \(errorMsg)"))
                    return
                }

                if let text = extractContent(from: data) {
                    messages.append(AIMessage(role: .assistant, content: text))
                    return
                }
            } catch {
                continue
            }
        }

        // 所有端点都失败
        messages.append(AIMessage(role: .assistant, content: "\(L10n.errorAIRequest): 所有端点均无法连接 (\(serverURL))"))
    }

    // MARK: - Send with Tools (Agent)

    /// OpenAI 带工具发送，返回响应文本
    private func sendOpenAIWithTools(content: String, systemPrompt: String) async -> String {
        let history = messages.map { msg in
            OpenAIChatRequest.Message(role: msg.role.rawValue, content: msg.content)
        }
        let systemMessage = OpenAIChatRequest.Message(role: "system", content: systemPrompt)
        let request = OpenAIChatRequest(model: selectedModel, messages: [systemMessage] + history)
        let endpoints = buildOpenAIEndpoints(serverURL)

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            if !apiKey.isEmpty { urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            if let (data, response) = try? await URLSession.shared.data(for: urlRequest),
               let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               let text = extractContent(from: data) {
                return text
            }
        }
        return ""
    }

    /// Ollama 带工具发送，返回响应文本
    private func sendOllamaWithTools(content: String, systemPrompt: String) async -> String {
        let history = messages.map { msg in
            OpenAIChatRequest.Message(role: msg.role.rawValue, content: msg.content)
        }
        let systemMessage = OpenAIChatRequest.Message(role: "system", content: systemPrompt)
        let body: [String: Any] = [
            "model": selectedModel,
            "messages": ([systemMessage] + history).map { ["role": $0.role, "content": $0.content] },
            "stream": false,
        ]

        guard let url = URL(string: "\(serverURL)/api/chat") else { return "" }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        urlRequest.timeoutInterval = 120

        if let (data, response) = try? await URLSession.shared.data(for: urlRequest),
           let httpResponse = response as? HTTPURLResponse,
           (200...299).contains(httpResponse.statusCode),
           let text = extractContent(from: data) {
            return text
        }
        return ""
    }

    /// Anthropic 带工具发送，返回响应文本
    private func sendAnthropicWithTools(content: String, systemPrompt: String) async -> String {
        let history = messages.map { msg in
            AnthropicRequest.Message(role: msg.role.rawValue, content: msg.content)
        }
        let request = AnthropicRequest(model: selectedModel, max_tokens: 4096, messages: history, system: systemPrompt)
        let endpoints = buildAnthropicEndpoints(serverURL)

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try? JSONEncoder().encode(request)
            urlRequest.timeoutInterval = 120

            if let (data, response) = try? await URLSession.shared.data(for: urlRequest),
               let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               let text = extractAnthropicContent(from: data) {
                return text
            }
        }
        return ""
    }

    private static func isCancellationError(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// 解析 HTTP 错误响应体，提取具体错误信息
    private func parseHTTPError(data: Data, statusCode: Int) -> String {
        let statusDesc: String
        switch statusCode {
        case 400: statusDesc = "请求格式错误"
        case 401: statusDesc = "API Key 无效或缺失"
        case 403: statusDesc = "访问被拒绝"
        case 404: statusDesc = "端点不存在"
        case 429: statusDesc = "请求过于频繁"
        case 500...599: statusDesc = "服务器错误"
        default: statusDesc = "HTTP \(statusCode)"
        }

        // 尝试解析 JSON 错误响应
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // OpenAI 格式: {"error": {"message": "...", "type": "..."}}
            if let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? ""
                let type = error["type"] as? String ?? ""
                let code = error["code"] as? String ?? ""
                var result = statusDesc
                if !type.isEmpty { result += " (\(type))" }
                if !code.isEmpty { result += " [\(code)]" }
                if !msg.isEmpty { result += ": \(msg)" }
                return result
            }
            // Anthropic 格式: {"error": {"message": "...", "type": "..."}}
            if let msg = json["error_message"] as? String {
                return "\(statusDesc): \(msg)"
            }
            // 直接 message 字段
            if let msg = json["message"] as? String {
                return "\(statusDesc): \(msg)"
            }
            // 直接 error 字段（字符串）
            if let msg = json["error"] as? String {
                return "\(statusDesc): \(msg)"
            }
        }

        // 纯文本错误
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty, text.count < 500 {
            return "\(statusDesc): \(text)"
        }

        return statusDesc
    }

    /// 从响应数据中提取文本内容，兼容多种 API 格式
    private func extractContent(from data: Data) -> String? {
        // 1. 标准 OpenAI 格式
        if let resp = try? JSONDecoder().decode(OpenAIChatResponse.self, from: data),
           let text = resp.choices.first?.message.content {
            return text
        }

        // 2. JSON 手动解析
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Anthropic: {"content": [{"type": "text", "text": "..."}]}
            if let content = json["content"] as? [[String: Any]] {
                let texts = content.compactMap { $0["text"] as? String }
                let joined = texts.joined()
                if !joined.isEmpty { return joined }
            }
            // Anthropic 错误
            if let error = json["error"] as? [String: Any],
               let msg = error["message"] as? String {
                return "Anthropic 错误: \(msg)"
            }
            // OpenAI: {"choices": [{"message": {"content": "..."}}]}
            if let choices = json["choices"] as? [[String: Any]] {
                for choice in choices {
                    // 标准 message.content
                    if let msg = choice["message"] as? [String: Any],
                       let text = msg["content"] as? String, !text.isEmpty {
                        return text
                    }
                    // 有些服务用 text 字段
                    if let text = choice["text"] as? String, !text.isEmpty {
                        return text
                    }
                    // delta.content (streaming 最后一条)
                    if let delta = choice["delta"] as? [String: Any],
                       let text = delta["content"] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
            // Ollama: {"message": {"content": "..."}}
            if let msg = json["message"] as? [String: Any],
               let text = msg["content"] as? String, !text.isEmpty {
                return text
            }
            // 直接 content / response / text / result / output
            for key in ["content", "response", "text", "result", "generated_text"] {
                if let text = json[key] as? String, !text.isEmpty {
                    return text
                }
            }
            // 嵌套 data.content / output.text / data.response
            if let dataObj = json["data"] as? [String: Any] {
                for key in ["content", "response", "text", "result"] {
                    if let text = dataObj[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
            if let output = json["output"] as? [String: Any] {
                for key in ["text", "content", "response"] {
                    if let text = output[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
            // 阿里云: {"output": {"choices": [{"message": {"content": "..."}}]}}
            if let output = json["output"] as? [String: Any],
               let choices = output["choices"] as? [[String: Any]],
               let first = choices.first,
               let msg = first["message"] as? [String: Any],
               let text = msg["content"] as? String, !text.isEmpty {
                return text
            }
            // 火山引擎: {"result": {"text": "..."}}
            if let result = json["result"] as? [String: Any] {
                for key in ["text", "content", "response"] {
                    if let text = result[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
        }

        // 3. 纯文本响应（非 JSON）
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty, !text.hasPrefix("{"), !text.hasPrefix("[") {
            return text
        }

        return nil
    }
}
