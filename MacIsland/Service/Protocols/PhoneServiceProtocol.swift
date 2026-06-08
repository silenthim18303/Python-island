//
//  PhoneServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation

// MARK: - Device Type

enum DeviceType: String, Codable {
    case iphone
    case android
    case ipad
    case mac
    case windows
    case linux
    case unknown

    var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .android: return "Android"
        case .ipad: return "iPad"
        case .mac: return "Mac"
        case .windows: return "Windows"
        case .linux: return "Linux"
        case .unknown: return "设备"
        }
    }

    var systemImage: String {
        switch self {
        case .iphone: return "iphone"
        case .android: return "smartphone"
        case .ipad: return "ipad"
        case .mac: return "desktopcomputer"
        case .windows: return "pc"
        case .linux: return "terminal"
        case .unknown: return "device.phone.portrait"
        }
    }
}

// MARK: - Message Type

enum DeviceMessageType: String, Codable {
    case notification
    case batteryStatus
    case deviceInfo
    case ping
    case pong
}

// MARK: - Connection State

enum DeviceConnectionState: String {
    case idle           // 未启动
    case advertising    // Bonjour 广播中，等待连接
    case connecting     // 正在建立连接
    case connected      // 已连接
    case disconnected   // 已断开
    case error          // 错误状态

    var displayName: String {
        switch self {
        case .idle: return "未启动"
        case .advertising: return "等待连接"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .disconnected: return "已断开"
        case .error: return "连接错误"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "device.phone.portrait.badge.xmark"
        case .advertising: return "antenna.radiowaves.left.and.right"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected: return "device.phone.portrait"
        case .disconnected: return "device.phone.portrait.badge.xmark"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Device Notification

struct DeviceNotification: Codable, Identifiable {
    let id: UUID
    let title: String
    let body: String
    let appName: String
    let timestamp: Date
}

// MARK: - Device Battery Status

struct DeviceBatteryStatus: Codable {
    let level: Double        // 0.0 - 1.0
    let isCharging: Bool
    let isLowPowerMode: Bool

    var percentString: String { "\(Int(level * 100))%" }

    var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        if level <= 0.10 { return "battery.0" }
        if level <= 0.25 { return "battery.25" }
        if level <= 0.50 { return "battery.50" }
        if level <= 0.75 { return "battery.75" }
        return "battery.100"
    }
}

// MARK: - Device Info

struct ConnectedDeviceInfo: Codable {
    let name: String         // "iPhone 16 Pro" / "Pixel 9"
    let model: String
    let systemVersion: String
    let deviceType: DeviceType

    var displayName: String { name }
}

// MARK: - Device Message (Wire Format)

struct DeviceMessage: Codable {
    let type: DeviceMessageType
    let payload: Data
    let timestamp: Date
    let messageID: UUID
}

// MARK: - Device Service Protocol

protocol DeviceServiceProtocol: AnyObject {
    /// 是否正在监听
    var isListening: Bool { get }
    /// 当前连接的设备信息
    var connectedDevice: ConnectedDeviceInfo? { get }
    /// 设备电池状态
    var deviceBattery: DeviceBatteryStatus? { get }
    /// 连接状态
    var connectionState: DeviceConnectionState { get }

    func startListening()
    func stopListening()
    func disconnect()
}
