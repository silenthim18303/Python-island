//
//  MemoStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Memo Store

/// 便签状态管理 — UserDefaults JSON 持久化
@MainActor
final class MemoStore: ObservableObject {
    static let shared = MemoStore()

    @Published var items: [MemoItem] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "memoItems"

    private init() {
        items = Self.load(defaults: defaults)
    }

    // MARK: - CRUD

    func addMemo(title: String = "", content: String = "") {
        let item = MemoItem(title: title, content: content)
        items.insert(item, at: 0)
    }

    func updateMemo(id: UUID, title: String? = nil, content: String? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let title { items[index].title = title }
        if let content { items[index].content = content }
        items[index].updatedAt = Date()
    }

    func togglePin(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].pinned.toggle()
    }

    func deleteMemo(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 按置顶优先、更新时间倒序排列
    var sortedItems: [MemoItem] {
        items.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.updatedAt > b.updatedAt
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults) -> [MemoItem] {
        guard let data = defaults.data(forKey: "memoItems"),
              let decoded = try? JSONDecoder().decode([MemoItem].self, from: data)
        else { return [] }
        return decoded
    }
}
