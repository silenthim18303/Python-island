//
//  SystemMonitorServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - System Stats

/// 系统监控数据
struct SystemStats {
    let cpuUsage: Double
    let memoryUsed: Double
    let memoryTotal: Double
    let memoryPercent: Double
    let diskUsed: Double
    let diskTotal: Double
    let diskPercent: Double

    static let empty = SystemStats(
        cpuUsage: 0, memoryUsed: 0, memoryTotal: 0, memoryPercent: 0,
        diskUsed: 0, diskTotal: 0, diskPercent: 0
    )
}

// MARK: - System Monitor Service Protocol

/// 系统监控服务协议
protocol SystemMonitorServiceProtocol: AnyObject {
    var stats: SystemStats { get }
    func startMonitoring()
    func stopMonitoring()
}
