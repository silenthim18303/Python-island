//
//  BookmarkItem.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import Foundation

// MARK: - Bookmark Item

/// URL 书签数据模型
struct BookmarkItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.createdAt = createdAt
    }
}
