//
//  SecureStorage.swift
//  MacIsland
//
//  统一的安全存储层 — 所有 Keychain 操作通过此类进行
//  使用 kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly 确保一致的安全级别
//

import Foundation
import Security

enum SecureStorage {
    private static let service = "geminimortal.MacIsland"

    /// 保存字符串到 Keychain
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // 删除旧值
        SecItemDelete(query as CFDictionary)

        // 写入新值
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// 从 Keychain 读取字符串
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 读取或创建默认值
    static func loadOrCreate(key: String, defaultValue: @autoclosure () -> String) -> String {
        if let value = load(key: key), !value.isEmpty {
            return value
        }
        let value = defaultValue()
        save(key: key, value: value)
        return value
    }

    /// 删除 Keychain 项
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
