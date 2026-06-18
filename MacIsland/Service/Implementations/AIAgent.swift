//
//  AIAgent.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - Agent Tool Definition

/// AI 可调用的工具定义
struct AgentTool: Codable {
    let name: String
    let description: String
    let parameters: ToolParameters

    struct ToolParameters: Codable {
        let type: String
        let properties: [String: PropertySchema]
        let required: [String]?

        struct PropertySchema: Codable {
            let type: String
            let description: String
            let `enum`: [String]?
        }
    }
}

/// 工具调用请求
struct ToolCall: Codable {
    let name: String
    let arguments: [String: AnyCodable]
}

/// 工具执行结果
struct ToolResult {
    let toolName: String
    let success: Bool
    let result: String
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = value as? String { try container.encode(s) }
        else if let i = value as? Int { try container.encode(i) }
        else if let d = value as? Double { try container.encode(d) }
        else if let b = value as? Bool { try container.encode(b) }
        else { try container.encodeNil() }
    }

    var stringValue: String { value as? String ?? "\(value)" }
    var intValue: Int { value as? Int ?? 0 }
    var doubleValue: Double { value as? Double ?? 0 }
    var boolValue: Bool { value as? Bool ?? false }
}

// MARK: - AI Agent

/// AI Agent — 解析 AI 响应中的工具调用并执行
@MainActor
final class AIAgent {
    static let shared = AIAgent()

    /// 可用工具列表
    let tools: [AgentTool] = [
        AgentTool(
            name: "get_weather",
            description: "获取当前天气信息，包括温度、湿度、风速等",
            parameters: .init(type: "object", properties: [:], required: nil)
        ),
        AgentTool(
            name: "get_system_status",
            description: "获取系统状态，包括 CPU 使用率、内存使用率、磁盘空间、电池电量",
            parameters: .init(type: "object", properties: [:], required: nil)
        ),
        AgentTool(
            name: "add_todo",
            description: "添加一个待办事项",
            parameters: .init(
                type: "object",
                properties: [
                    "title": .init(type: "string", description: "待办事项标题", enum: nil)
                ],
                required: ["title"]
            )
        ),
        AgentTool(
            name: "get_todos",
            description: "获取所有待办事项列表",
            parameters: .init(type: "object", properties: [:], required: nil)
        ),
        AgentTool(
            name: "set_timer",
            description: "设置一个倒计时器",
            parameters: .init(
                type: "object",
                properties: [
                    "minutes": .init(type: "integer", description: "倒计时分钟数", enum: nil),
                    "label": .init(type: "string", description: "计时器标签（可选）", enum: nil)
                ],
                required: ["minutes"]
            )
        ),
        AgentTool(
            name: "search_stock",
            description: "搜索股票信息",
            parameters: .init(
                type: "object",
                properties: [
                    "keyword": .init(type: "string", description: "股票代码或名称", enum: nil)
                ],
                required: ["keyword"]
            )
        ),
        AgentTool(
            name: "get_stock_quote",
            description: "获取指定股票的实时行情",
            parameters: .init(
                type: "object",
                properties: [
                    "symbol": .init(type: "string", description: "股票代码", enum: nil)
                ],
                required: ["symbol"]
            )
        ),
        AgentTool(
            name: "take_note",
            description: "创建一个便签",
            parameters: .init(
                type: "object",
                properties: [
                    "content": .init(type: "string", description: "便签内容", enum: nil)
                ],
                required: ["content"]
            )
        ),
        AgentTool(
            name: "get_time",
            description: "获取当前日期和时间",
            parameters: .init(type: "object", properties: [:], required: nil)
        ),
    ]

    /// 生成工具定义的 JSON（用于 API 请求）
    func toolsJSON() -> String {
        guard let data = try? JSONEncoder().encode(tools),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// 从 AI 响应中提取工具调用
    func extractToolCalls(from content: String) -> [ToolCall] {
        // 尝试解析 JSON 格式的工具调用
        // 格式1: [{"name": "tool_name", "arguments": {...}}]
        // 格式2: {"tool_calls": [{"function": {"name": "...", "arguments": {...}}}]}
        // 格式3: [TOOL_CALL] name=tool_name arg1=value1 [/TOOL_CALL]

        var calls: [ToolCall] = []

        // 尝试 JSON 格式
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) {
            // 格式1: 直接数组
            if let arr = json as? [[String: Any]] {
                for item in arr {
                    if let name = item["name"] as? String {
                        let args = item["arguments"] as? [String: Any] ?? [:]
                        let codableArgs = args.mapValues { AnyCodable($0) }
                        calls.append(ToolCall(name: name, arguments: codableArgs))
                    }
                }
            }
            // 格式2: OpenAI function_call 格式
            if let obj = json as? [String: Any],
               let toolCalls = obj["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    if let func_ = tc["function"] as? [String: Any],
                       let name = func_["name"] as? String {
                        let argsStr = func_["arguments"] as? String ?? "{}"
                        let argsData = argsStr.data(using: .utf8) ?? Data()
                        let args = (try? JSONSerialization.jsonObject(with: argsData) as? [String: Any]) ?? [:]
                        let codableArgs = args.mapValues { AnyCodable($0) }
                        calls.append(ToolCall(name: name, arguments: codableArgs))
                    }
                }
            }
        }

        // 格式3: 标签格式 [TOOL_CALL]name=xxx[/TOOL_CALL]
        let pattern = #"\[TOOL_CALL\](.*?)\[/TOOL_CALL\]"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                let inner = nsString.substring(with: match.range(at: 1))
                let parts = inner.split(separator: " ", maxSplits: 1)
                if let namePart = parts.first {
                    let name = String(namePart).replacingOccurrences(of: "name=", with: "")
                    var args: [String: AnyCodable] = [:]
                    if parts.count > 1 {
                        let argsStr = String(parts[1])
                        for pair in argsStr.split(separator: " ") {
                            let kv = pair.split(separator: "=", maxSplits: 1)
                            if kv.count == 2 {
                                args[String(kv[0])] = AnyCodable(String(kv[1]))
                            }
                        }
                    }
                    calls.append(ToolCall(name: name, arguments: args))
                }
            }
        }

        return calls
    }

    /// 执行工具调用
    func execute(toolCall: ToolCall) async -> ToolResult {
        switch toolCall.name {
        case "get_weather":
            return await executeGetWeather()
        case "get_system_status":
            return executeGetSystemStatus()
        case "add_todo":
            return executeAddTodo(args: toolCall.arguments)
        case "get_todos":
            return executeGetTodos()
        case "set_timer":
            return executeSetTimer(args: toolCall.arguments)
        case "search_stock":
            return await executeSearchStock(args: toolCall.arguments)
        case "get_stock_quote":
            return await executeGetStockQuote(args: toolCall.arguments)
        case "take_note":
            return executeTakeNote(args: toolCall.arguments)
        case "get_time":
            return executeGetTime()
        default:
            return ToolResult(toolName: toolCall.name, success: false, result: "未知工具: \(toolCall.name)")
        }
    }

    // MARK: - Tool Implementations

    private func executeGetWeather() async -> ToolResult {
        let weather = QWeatherService(config: .autoDetect(apiKey: AppSettings.shared.weatherEffectiveAPIKey, apiHost: AppSettings.shared.weatherEffectiveAPIHost, locationID: "101010100"))
        await weather.fetchWeather()
        let w = weather.weather
        let result = """
        城市: \(w.cityName) \(w.districtName)
        天气: \(w.description)
        温度: \(Int(w.temperature))°C (最高\(Int(w.temperatureMax))° / 最低\(Int(w.temperatureMin))°)
        湿度: \(w.humidity)%
        风速: \(String(format: "%.0f", w.windSpeed)) km/h
        """
        return ToolResult(toolName: "get_weather", success: true, result: result)
    }

    private func executeGetSystemStatus() -> ToolResult {
        let monitor = SystemMonitorServiceImpl(monitor: DefaultSystemMonitor())
        let stats = monitor.stats
        let result = """
        CPU: \(String(format: "%.1f", stats.cpuUsage))% (\(stats.cpuCoreCount) 核)
        内存: \(String(format: "%.1f", stats.memoryPercent))% (\(String(format: "%.1f", stats.memoryUsed))G / \(String(format: "%.0f", stats.memoryTotal))G)
        磁盘: \(String(format: "%.1f", stats.diskPercent))% (\(String(format: "%.0f", stats.diskUsed))G / \(String(format: "%.0f", stats.diskTotal))G)
        电池: \(String(format: "%.0f", stats.batteryLevel))% \(stats.batteryIsCharging ? "充电中" : "")
        网络: \(stats.networkConnected ? stats.networkType.rawValue : "未连接")
        """
        return ToolResult(toolName: "get_system_status", success: true, result: result)
    }

    private func executeAddTodo(args: [String: AnyCodable]) -> ToolResult {
        guard let title = args["title"]?.stringValue, !title.isEmpty else {
            return ToolResult(toolName: "add_todo", success: false, result: "缺少标题参数")
        }
        let store = TodoStore.shared
        store.addTodo(text: title)
        return ToolResult(toolName: "add_todo", success: true, result: "已添加待办: \(title)")
    }

    private func executeGetTodos() -> ToolResult {
        let todos = TodoStore.shared.items
        if todos.isEmpty {
            return ToolResult(toolName: "get_todos", success: true, result: "暂无待办事项")
        }
        let list = todos.prefix(10).map { item in
            let status = item.done ? "✅" : "⬜"
            return "\(status) \(item.text)"
        }.joined(separator: "\n")
        return ToolResult(toolName: "get_todos", success: true, result: "待办事项:\n\(list)")
    }

    private func executeSetTimer(args: [String: AnyCodable]) -> ToolResult {
        guard let minutes = args["minutes"]?.intValue, minutes > 0 else {
            return ToolResult(toolName: "set_timer", success: false, result: "缺少有效的分钟数参数")
        }
        let label = args["label"]?.stringValue ?? "计时器"
        let timerService = TimerService()
        timerService.startCountdown()
        return ToolResult(toolName: "set_timer", success: true, result: "已设置 \(minutes) 分钟倒计时 (\(label))")
    }

    private func executeSearchStock(args: [String: AnyCodable]) async -> ToolResult {
        guard let keyword = args["keyword"]?.stringValue, !keyword.isEmpty else {
            return ToolResult(toolName: "search_stock", success: false, result: "缺少搜索关键词")
        }
        do {
            let results = try await StockDataProvider.shared.searchStocks(keyword: keyword, market: nil)
            if results.isEmpty {
                return ToolResult(toolName: "search_stock", success: true, result: "未找到相关股票")
            }
            let list = results.prefix(5).map { "\($0.name) (\($0.id)) - \($0.market.displayName)" }.joined(separator: "\n")
            return ToolResult(toolName: "search_stock", success: true, result: "搜索结果:\n\(list)")
        } catch {
            return ToolResult(toolName: "search_stock", success: false, result: "搜索失败: \(error.localizedDescription)")
        }
    }

    private func executeGetStockQuote(args: [String: AnyCodable]) async -> ToolResult {
        guard let symbol = args["symbol"]?.stringValue, !symbol.isEmpty else {
            return ToolResult(toolName: "get_stock_quote", success: false, result: "缺少股票代码参数")
        }
        // 从自选股中查找
        if let quote = StockStore.shared.getQuote(symbol: symbol) {
            let result = """
            \(quote.name) (\(quote.symbol))
            价格: \(quote.priceString)
            涨跌: \(quote.changeAmountString) (\(quote.changePercentString))
            今开: \(String(format: "%.2f", quote.openPrice))
            最高: \(String(format: "%.2f", quote.highPrice))
            最低: \(String(format: "%.2f", quote.lowPrice))
            """
            return ToolResult(toolName: "get_stock_quote", success: true, result: result)
        }
        return ToolResult(toolName: "get_stock_quote", success: false, result: "未找到股票 \(symbol) 的行情数据，请先添加到自选股")
    }

    private func executeTakeNote(args: [String: AnyCodable]) -> ToolResult {
        guard let content = args["content"]?.stringValue, !content.isEmpty else {
            return ToolResult(toolName: "take_note", success: false, result: "缺少便签内容")
        }
        let store = MemoStore.shared
        store.addMemo(content: content)
        return ToolResult(toolName: "take_note", success: true, result: "已创建便签: \(content)")
    }

    private func executeGetTime() -> ToolResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm:ss"
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        let result = formatter.string(from: Date())
        return ToolResult(toolName: "get_time", success: true, result: result)
    }
}
