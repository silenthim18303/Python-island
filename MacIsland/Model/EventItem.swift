//
//  EventItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Event Type

/// 事件类型
enum EventType: String, Codable, CaseIterable, Identifiable {
    case countdown = "倒数日"
    case anniversary = "纪念日"
    case birthday = "生日"
    case holiday = "节日"
    case exam = "考试"

    var id: String { rawValue }
}

// MARK: - Event Item

/// 倒计时/纪念日事件数据模型
struct EventItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var eventType: EventType
    var targetDate: Date
    var createdAt: Date
    var enabled: Bool
    var backgroundImagePath: String?

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        eventType: EventType = .countdown,
        targetDate: Date,
        createdAt: Date = Date(),
        enabled: Bool = true,
        backgroundImagePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.eventType = eventType
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.enabled = enabled
        self.backgroundImagePath = backgroundImagePath
    }

    /// 距离目标日期的天数（正数为未来，负数为过去）
    var daysRemaining: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: targetDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 是否已过期
    var isPast: Bool { daysRemaining < 0 }
}
