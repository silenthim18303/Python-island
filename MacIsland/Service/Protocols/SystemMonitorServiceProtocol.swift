//
//  SystemMonitorServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Network Status

/// 网络连接状态
enum NetworkConnectionType: String {
    case wifi = "Wi-Fi"
    case ethernet = "以太网"
    case cellular = "蜂窝"
    case none = "无连接"
    case unknown = "未知"
}

// MARK: - System Stats

/// 系统监控数据
struct SystemStats {
    // CPU
    let cpuUsage: Double
    let cpuSystem: Double
    let cpuUser: Double
    let cpuIdle: Double
    let cpuCoreCount: Int
    let cpuTemperature: Double  // °C, 0 表示不可用

    // 内存
    let memoryUsed: Double
    let memoryTotal: Double
    let memoryPercent: Double
    let memoryPressure: Double
    let memoryApp: Double
    let memoryWired: Double
    let memoryCompressed: Double

    // 磁盘
    let diskUsed: Double
    let diskTotal: Double
    let diskPercent: Double

    // 电池
    let batteryLevel: Double
    let batteryIsCharging: Bool
    let batteryMaxCapacity: Double
    let batteryCycleCount: Int
    let batteryTemperature: Double

    // 网络
    let networkConnected: Bool
    let networkType: NetworkConnectionType
    let networkInterface: String
    let localIP: String
    let uploadSpeed: Double
    let downloadSpeed: Double

    static let empty = SystemStats(
        cpuUsage: 0, cpuSystem: 0, cpuUser: 0, cpuIdle: 100,
        cpuCoreCount: 0, cpuTemperature: 0,
        memoryUsed: 0, memoryTotal: 0, memoryPercent: 0, memoryPressure: 0,
        memoryApp: 0, memoryWired: 0, memoryCompressed: 0,
        diskUsed: 0, diskTotal: 0, diskPercent: 0,
        batteryLevel: 100, batteryIsCharging: false, batteryMaxCapacity: 100,
        batteryCycleCount: 0, batteryTemperature: 0,
        networkConnected: false, networkType: .none, networkInterface: "",
        localIP: "", uploadSpeed: 0, downloadSpeed: 0
    )
}

// MARK: - System Monitor Service Protocol

/// 系统监控服务协议
protocol SystemMonitorServiceProtocol: AnyObject {
    var stats: SystemStats { get }
    func startMonitoring()
    func stopMonitoring()
    /// 网络变化回调（状态改变时触发）
    var onNetworkChange: ((Bool, NetworkConnectionType) -> Void)? { get set }
}
