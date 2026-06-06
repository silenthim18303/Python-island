//
//  AlarmStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import Combine

// MARK: - Alarm Store

/// 闹钟状态管理
@MainActor
final class AlarmStore: ObservableObject {
    static let shared = AlarmStore()

    @Published var items: [AlarmItem] {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "alarmItems"

    private init() {
        items = Self.load(defaults: defaults)
    }

    // MARK: - CRUD

    func addAlarm(label: String = L10n.defaultAlarmLabel, hour: Int = 8, minute: Int = 0, repeatDays: Set<Weekday> = []) {
        let item = AlarmItem(label: label, hour: hour, minute: minute, repeatDays: repeatDays)
        items.append(item)
    }

    func toggleAlarm(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].enabled.toggle()
    }

    func deleteAlarm(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func updateAlarm(id: UUID, label: String? = nil, hour: Int? = nil, minute: Int? = nil, repeatDays: Set<Weekday>? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let label { items[index].label = label }
        if let hour { items[index].hour = hour }
        if let minute { items[index].minute = minute }
        if let repeatDays { items[index].repeatDays = repeatDays }
    }

    /// 按时间排序
    var sortedItems: [AlarmItem] {
        items.sorted { a, b in
            if a.hour != b.hour { return a.hour < b.hour }
            return a.minute < b.minute
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(defaults: UserDefaults) -> [AlarmItem] {
        guard let data = defaults.data(forKey: "alarmItems"),
              let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data)
        else { return [] }
        return decoded
    }
}
