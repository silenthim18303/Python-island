//
//  LocalAIService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation
import Combine

/// 本地 AI 服务 - 无需外部 API 的智能助手
@MainActor
final class LocalAIService: ObservableObject {
    static let shared = LocalAIService()

    @Published var isProcessing = false
    @Published var lastResponse = ""

    // MARK: - 知识库

    private let knowledgeBase: [String: [String]] = [
        // 问候
        "你好": ["你好！我是 MacIsland 智能助手，有什么可以帮你的吗？", "嗨！很高兴见到你！", "你好呀！今天有什么需要帮忙的吗？"],
        "hello": ["Hello! I'm MacIsland assistant, how can I help you?", "Hi there! Nice to meet you!", "Hey! What can I do for you today?"],
        "hi": ["Hi! How are you?", "Hey there!", "Hello! What's up?"],

        // 天气
        "天气": ["今天天气不错，适合出门走走！", "记得带伞，可能会下雨。", "今天气温适宜，可以穿轻薄的衣服。"],
        "weather": ["The weather looks nice today!", "Don't forget your umbrella, it might rain.", "Today's temperature is pleasant."],

        // 功能
        "功能": ["我可以帮你：\n1. 播放/暂停音乐\n2. 查看天气\n3. 设置计时器\n4. 管理待办事项\n5. 聊天解闷\n\n有什么需要帮忙的吗？"],
        "features": ["I can help you with:\n1. Play/pause music\n2. Check weather\n3. Set timers\n4. Manage todos\n5. Chat\n\nWhat do you need?"],

        // 音乐
        "音乐": ["正在为你播放音乐！", "音乐已暂停。", "让我为你切到下一首歌。"],
        "music": ["Playing music for you!", "Music paused.", "Let me skip to the next song."],

        // 计时器
        "计时器": ["计时器已启动！", "计时器已暂停。", "计时器已重置。"],
        "timer": ["Timer started!", "Timer paused.", "Timer reset."],

        // 待办
        "待办": ["你有几项待办事项需要处理。", "所有待办都完成了！干得漂亮！", "让我帮你查看待办列表。"],
        "todo": ["You have some todos to complete.", "All todos are done! Great job!", "Let me check your todo list."],

        // 壁纸
        "壁纸": ["你可以在这里更换壁纸，让桌面更个性化！", "壁纸已更新，看起来不错！"],
        "wallpaper": ["You can change your wallpaper here to personalize your desktop!", "Wallpaper updated, looks great!"],

        // 帮助
        "帮助": ["你可以问我：\n- 今天天气怎么样？\n- 现在几点了？\n- 播放音乐\n- 设置计时器\n- 有什么功能？\n\n随时告诉我你需要什么！"],
        "help": ["You can ask me:\n- What's the weather like?\n- What time is it?\n- Play music\n- Set a timer\n- What features do you have?\n\nLet me know what you need!"],

        // 笑话
        "笑话": ["为什么程序员总是分不清万圣节和圣诞节？因为 Oct 31 = Dec 25 😄", "什么动物最懒？当然是懒羊羊啦！🐑"],
        "jokes": ["Why do programmers confuse Halloween and Christmas? Because Oct 31 = Dec 25 😄", "What's a programmer's favorite hangout place? Foo Bar! 🍺"],

        // 感谢
        "谢谢": ["不客气！随时为你服务！", "很高兴能帮到你！", "别客气，有需要随时找我！"],
        "thanks": ["You're welcome!", "Glad I could help!", "Anytime!"],

        // 再见
        "再见": ["再见！下次见！", "拜拜！有需要随时找我！", "再见，祝你有美好的一天！"],
        "goodbye": ["Goodbye! See you next time!", "Bye! Let me know if you need anything!", "See you, have a great day!"],
    ]

    // MARK: - 公共方法

    /// 处理用户输入
    func process(_ input: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        // 模拟思考延迟
        try? await Task.sleep(nanoseconds: 500_000_000)

        let response = generateResponse(for: input)
        lastResponse = response
        return response
    }

    // MARK: - 私有方法

    /// 生成回复
    private func generateResponse(for input: String) -> String {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 时间相关
        if lowercased.contains("几点") || lowercased.contains("时间") || lowercased.contains("what time") {
            return "现在是 \(formattedTime())。"
        }

        // 日期相关
        if lowercased.contains("几号") || lowercased.contains("日期") || lowercased.contains("what date") {
            return "今天是 \(formattedDate())。"
        }

        // 精确匹配
        if let responses = knowledgeBase[lowercased], let response = responses.randomElement() {
            return response
        }

        // 模糊匹配
        for (key, responses) in knowledgeBase {
            if lowercased.contains(key) || key.contains(lowercased) {
                return responses.randomElement()!
            }
        }

        // 计算
        if let result = calculate(lowercased) {
            return "计算结果是：\(result)"
        }

        // 默认回复
        let defaults = [
            "这个问题我还在学习中，你可以问我其他问题！",
            "抱歉，我还不太理解这个问题。你可以问我天气、时间、音乐等功能。",
            "让我想想... 你可以试试问我「有什么功能？」",
            "这个问题有点难，你可以换个方式问我吗？",
        ]

        return defaults.randomElement()!
    }

    /// 简单计算
    private func calculate(_ input: String) -> String? {
        // 支持简单四则运算
        let patterns = [
            "^(\\d+)\\s*[+]\\s*(\\d+)$",
            "^(\\d+)\\s*[-]\\s*(\\d+)$",
            "^(\\d+)\\s*[*×]\\s*(\\d+)$",
            "^(\\d+)\\s*[÷/]\\s*(\\d+)$",
        ]

        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                let num1 = Double(input[Range(match.range(at: 1), in: input)!])!
                let num2 = Double(input[Range(match.range(at: 2), in: input)!])!

                var result: Double
                switch index {
                case 0: result = num1 + num2
                case 1: result = num1 - num2
                case 2: result = num1 * num2
                case 3:
                    guard num2 != 0 else { return "不能除以零哦！" }
                    result = num1 / num2
                default: return nil
                }

                return result.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(result))
                    : String(format: "%.2f", result)
            }
        }

        return nil
    }

    /// 格式化时间
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    /// 格式化日期
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
    }
}
