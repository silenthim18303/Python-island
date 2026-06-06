//
//  EventStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Event Store

/// 倒计时/纪念日状态管理
@MainActor
final class EventStore: ObservableObject {
    static let shared = EventStore()

    @Published var items: [EventItem] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "eventItems"

    private init() {
        items = Self.load(defaults: defaults)

        // 订阅事件变化，同步小组件
        $items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.updateWidgetData(items)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateWidgetData(_ items: [EventItem]) {
        let widgetItems = items.filter { $0.enabled }.prefix(10).map { item -> [String: Any] in
            [
                "id": item.id.uuidString,
                "name": item.title,
                "targetDate": item.targetDate.timeIntervalSince1970,
                "type": item.eventType.rawValue
            ]
        }
        WidgetDataManager.shared.updateEvents(items: widgetItems)
    }

    // MARK: - CRUD

    func addEvent(title: String, type: EventType, targetDate: Date) {
        let item = EventItem(title: title, eventType: type, targetDate: targetDate)
        items.append(item)
    }

    func toggleEvent(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].enabled.toggle()
    }

    func deleteEvent(id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// 按距离目标日期排序（最近的在前）
    var sortedItems: [EventItem] {
        items.sorted { $0.targetDate < $1.targetDate }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults) -> [EventItem] {
        guard let data = defaults.data(forKey: "eventItems"),
              let decoded = try? JSONDecoder().decode([EventItem].self, from: data)
        else { return [] }
        return decoded
    }
}
