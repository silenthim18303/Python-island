//
//  BookmarkStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Bookmark Store

/// URL 书签状态管理
@MainActor
final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published var items: [BookmarkItem] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "bookmarkItems"

    private init() {
        items = Self.load(defaults: defaults)
    }

    // MARK: - CRUD

    func addBookmark(title: String, url: String) {
        let item = BookmarkItem(title: title, url: url)
        items.insert(item, at: 0)
    }

    func deleteBookmark(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 在浏览器中打开书签
    func openBookmark(_ item: BookmarkItem) {
        guard let url = URL(string: item.url) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults) -> [BookmarkItem] {
        guard let data = defaults.data(forKey: "bookmarkItems"),
              let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data)
        else { return [] }
        return decoded
    }
}
