//
//  TodoStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Todo Store

/// 待办事项状态管理 — UserDefaults JSON 持久化
@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published var items: [TodoItem] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "todoItems"

    // MARK: - Init

    private init() {
        items = Self.load(defaults: defaults)

        // 订阅待办变化，同步小组件
        $items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.updateWidgetData(items)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateWidgetData(_ items: [TodoItem]) {
        let activeItems = items.filter { $0.deletedAt == nil }
        let completedCount = activeItems.filter { $0.done }.count

        let widgetItems = activeItems.prefix(10).map { item -> [String: Any] in
            [
                "id": item.id.uuidString,
                "title": item.text,
                "completed": item.done
            ]
        }

        WidgetDataManager.shared.updateTodo(
            totalCount: activeItems.count,
            completedCount: completedCount,
            items: widgetItems
        )
    }

    // MARK: - CRUD

    func addTodo(text: String, priority: Priority = .p2) {
        let item = TodoItem(text: text, priority: priority)
        items.append(item)
    }

    func toggleTodo(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].done.toggle()
    }

    /// 软删除 — 标记 deletedAt 而非移除
    func deleteTodo(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].deletedAt = Date()
    }

    /// 恢复已删除的待办
    func restoreTodo(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].deletedAt = nil
    }

    /// 永久删除
    func permanentDelete(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 清空回收站
    func emptyTrash() {
        items.removeAll { $0.deletedAt != nil }
    }

    func updateDescription(id: UUID, description: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].description = description
    }

    // MARK: - Sub Items

    func addSubItem(parentId: UUID, text: String, priority: Priority = .p2) {
        guard let index = items.firstIndex(where: { $0.id == parentId }) else { return }
        let sub = TodoItem(text: text, priority: priority)
        items[index].subItems.append(sub)
    }

    func toggleSubItem(parentId: UUID, subId: UUID) {
        guard let parentIndex = items.firstIndex(where: { $0.id == parentId }),
              let subIndex = items[parentIndex].subItems.firstIndex(where: { $0.id == subId })
        else { return }
        items[parentIndex].subItems[subIndex].done.toggle()
    }

    func deleteSubItem(parentId: UUID, subId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == parentId }) else { return }
        items[index].subItems.removeAll { $0.id == subId }
    }

    // MARK: - Stats

    /// 未删除的活跃项
    var activeItems: [TodoItem] { items.filter { $0.deletedAt == nil } }
    /// 已删除的项（回收站）
    var deletedItems: [TodoItem] { items.filter { $0.deletedAt != nil } }

    var totalCount: Int { activeItems.count }
    var doneCount: Int { activeItems.filter(\.done).count }
    var undoneCount: Int { totalCount - doneCount }
    var p0Count: Int { activeItems.filter { $0.priority == .p0 && !$0.done }.count }
    var p1Count: Int { activeItems.filter { $0.priority == .p1 && !$0.done }.count }
    var p2Count: Int { activeItems.filter { $0.priority == .p2 && !$0.done }.count }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults) -> [TodoItem] {
        guard let data = defaults.data(forKey: "todoItems"),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        else { return [] }
        return decoded
    }
}
