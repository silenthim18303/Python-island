//
//  SystemMonitorServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine

/// 系统监控服务实现
final class SystemMonitorServiceImpl: SystemMonitorServiceProtocol, ObservableObject {
    @Published private(set) var stats: SystemStats = .empty

    private var timer: Timer?
    private let monitor: SystemMonitorProtocol

    init(monitor: SystemMonitorProtocol = DefaultSystemMonitor()) {
        self.monitor = monitor
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.update() }
        }
        update()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private Methods

    private func update() {
        let cpu = monitor.cpuUsage()
        let (memUsed, memTotal) = monitor.memoryUsage()
        let (diskUsed, diskTotal) = monitor.diskUsage()

        stats = SystemStats(
            cpuUsage: cpu,
            memoryUsed: memUsed,
            memoryTotal: memTotal,
            memoryPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0,
            diskUsed: diskUsed,
            diskTotal: diskTotal,
            diskPercent: diskTotal > 0 ? diskUsed / diskTotal * 100 : 0
        )
    }
}

// MARK: - System Monitor Protocol

protocol SystemMonitorProtocol {
    func cpuUsage() -> Double
    func memoryUsage() -> (used: Double, total: Double)
    func diskUsage() -> (used: Double, total: Double)
}

// MARK: - Default System Monitor

struct DefaultSystemMonitor: SystemMonitorProtocol {
    func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), HOST_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo) == KERN_SUCCESS,
              let cpuInfo = cpuInfo else { return 0 }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(numCPUInfo) * MemoryLayout<integer_t>.size))
        }

        var total: Double = 0
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
            let sum = user + system + idle + nice
            if sum > 0 {
                total += (user + system + nice) / sum * 100
            }
        }
        return total / Double(numCPUs)
    }

    func memoryUsage() -> (used: Double, total: Double) {
        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824

        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size) / 4

        guard withUnsafeMutablePointer(to: &stats, {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }) == KERN_SUCCESS else { return (0, totalGB) }

        let pageSize = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.inactive_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * pageSize / 1_073_741_824

        return (used, totalGB)
    }

    func diskUsage() -> (used: Double, total: Double) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let totalSize = attrs[.systemSize] as? NSNumber,
              let freeSize = attrs[.systemFreeSize] as? NSNumber else {
            return (0, 0)
        }

        let totalGB = totalSize.doubleValue / 1_073_741_824
        let freeGB = freeSize.doubleValue / 1_073_741_824
        return (totalGB - freeGB, totalGB)
    }
}
