//
//  NotificationCenterStore.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/5.
//

import Foundation
import Combine

// MARK: - Notification Record

/// 单条通知记录
struct NotificationRecord: Identifiable, Codable {
    let id: UUID
    let title: String
    let body: String
    let timestamp: Date
    let source: NotificationSource

    init(title: String, body: String, source: NotificationSource) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.timestamp = Date()
        self.source = source
    }
}

// MARK: - Notification Source

/// 通知来源
enum NotificationSource: String, Codable {
    case timer      = "timer"       // 番茄钟/倒计时
    case clipboard  = "clipboard"   // 剪贴板链接
    case music      = "music"       // 音乐变化
    case system     = "system"      // 系统通知
    case other      = "other"

    var displayName: String {
        switch self {
        case .timer: return "计时器"
        case .clipboard: return "剪贴板"
        case .music: return "音乐"
        case .system: return "系统"
        case .other: return "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: return "timer"
        case .clipboard: return "doc.on.clipboard"
        case .music: return "music.note"
        case .system: return "gear"
        case .other: return "bell"
        }
    }
}

// MARK: - Notification Center Store

/// 通知中心 — 统一管理所有通知历史
@MainActor
final class NotificationCenterStore: ObservableObject {
    static let shared = NotificationCenterStore()

    @Published private(set) var records: [NotificationRecord] = []
    @Published var unreadCount: Int = 0

    /// 最大记录数（超过自动清理旧记录）
    private let maxRecords = 200

    private let defaults = UserDefaults.standard
    private let storageKey = "notificationRecords"

    private init() {
        loadRecords()
    }

    // MARK: - Public API

    /// 添加一条通知记录
    func addNotification(title: String, body: String, source: NotificationSource = .other) {
        let record = NotificationRecord(title: title, body: body, source: source)
        records.insert(record, at: 0)
        unreadCount += 1

        // 超过上限时清理旧记录
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        saveRecords()
    }

    /// 标记所有为已读
    func markAllRead() {
        unreadCount = 0
    }

    /// 清空所有记录
    func clearAll() {
        records.removeAll()
        unreadCount = 0
        saveRecords()
    }

    /// 删除单条记录
    func removeRecord(_ record: NotificationRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
    }

    /// 按来源过滤
    func records(for source: NotificationSource) -> [NotificationRecord] {
        records.filter { $0.source == source }
    }

    // MARK: - Persistence

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadRecords() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NotificationRecord].self, from: data) else {
            return
        }
        records = decoded
    }
}
