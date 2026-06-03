//
//  MemoItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Memo Item

/// 便签数据模型
struct MemoItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var pinned: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pinned = pinned
    }
}
