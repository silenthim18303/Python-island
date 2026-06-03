//
//  TodoItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Priority

/// 待办优先级
enum Priority: String, Codable, CaseIterable, Identifiable {
    case p0 = "P0"
    case p1 = "P1"
    case p2 = "P2"

    var id: String { rawValue }

    var label: String { rawValue }

    var colorHex: String {
        switch self {
        case .p0: return "#FF5252"
        case .p1: return "#FFAB40"
        case .p2: return "#69C0FF"
        }
    }
}

// MARK: - TodoItem

/// 待办事项数据模型
struct TodoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var done: Bool
    var createdAt: Date
    var priority: Priority
    var description: String
    var subItems: [TodoItem]
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        text: String,
        done: Bool = false,
        createdAt: Date = Date(),
        priority: Priority = .p2,
        description: String = "",
        subItems: [TodoItem] = [],
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.done = done
        self.createdAt = createdAt
        self.priority = priority
        self.description = description
        self.subItems = subItems
        self.deletedAt = deletedAt
    }
}
