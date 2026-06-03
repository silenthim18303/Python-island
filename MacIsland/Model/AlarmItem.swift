//
//  AlarmItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Alarm Item

/// 闹钟数据模型
struct AlarmItem: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    var hour: Int
    var minute: Int
    var enabled: Bool
    var repeatDays: Set<Weekday>

    init(
        id: UUID = UUID(),
        label: String = "闹钟",
        hour: Int = 8,
        minute: Int = 0,
        enabled: Bool = true,
        repeatDays: Set<Weekday> = []
    ) {
        self.id = id
        self.label = label
        self.hour = hour
        self.minute = minute
        self.enabled = enabled
        self.repeatDays = repeatDays
    }

    /// 格式化显示时间 "HH:mm"
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// 是否为一次性闹钟（未选择任何重复日）
    var isOneTime: Bool { repeatDays.isEmpty }
}

// MARK: - Weekday

/// 星期几
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sun: return "日"
        case .mon: return "一"
        case .tue: return "二"
        case .wed: return "三"
        case .thu: return "四"
        case .fri: return "五"
        case .sat: return "六"
        }
    }
}
