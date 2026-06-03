//
//  SystemMonitorServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine
import Network
import IOKit
import IOKit.ps

/// 系统监控服务实现
final class SystemMonitorServiceImpl: SystemMonitorServiceProtocol, ObservableObject {
    @Published private(set) var stats: SystemStats = .empty
    var onNetworkChange: ((Bool, NetworkConnectionType) -> Void)?

    private var timer: Timer?
    private let monitor: SystemMonitorProtocol
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.macisland.network")
    private var currentNetworkConnected = false
    private var currentNetworkType: NetworkConnectionType = .none

    // 网络速度追踪
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastSpeedCheck: Date = Date()

    init(monitor: SystemMonitorProtocol = DefaultSystemMonitor()) {
        self.monitor = monitor
    }

    func startMonitoring() {
        // 系统资源轮询
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.update() }
        }
        update()

        // 网络变化监听
        startNetworkMonitor()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        pathMonitor.cancel()
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let type = self?.resolveNetworkType(path: path) ?? .none

            DispatchQueue.main.async {
                let changed = self?.currentNetworkConnected != connected
                self?.currentNetworkConnected = connected
                self?.currentNetworkType = type
                self?.update()

                if changed {
                    self?.onNetworkChange?(connected, type)
                }
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    private func resolveNetworkType(path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.status == .satisfied { return .unknown }
        return .none
    }

    // MARK: - Network Speed

    private func getNetworkSpeed() -> (upload: Double, download: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            if name.hasPrefix("en") || name.hasPrefix("awdl") || name.hasPrefix("llw") {
                let addr = interface.ifa_addr.pointee
                if addr.sa_family == UInt8(AF_LINK) {
                    let data = unsafeBitCast(interface.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                    totalBytesOut += UInt64(data.pointee.ifi_obytes)
                    totalBytesIn += UInt64(data.pointee.ifi_ibytes)
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastSpeedCheck)
        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0

        if elapsed > 0.5 && lastBytesIn > 0 {
            uploadSpeed = Double(totalBytesOut - lastBytesOut) / elapsed
            downloadSpeed = Double(totalBytesIn - lastBytesIn) / elapsed
        }

        lastBytesIn = totalBytesIn
        lastBytesOut = totalBytesOut
        lastSpeedCheck = now

        return (uploadSpeed, downloadSpeed)
    }

    // MARK: - Battery

    private func getBatteryInfo() -> (level: Double, isCharging: Bool, maxCapacity: Double, cycleCount: Int, temperature: Double) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first
        else {
            return (100, false, 100, 0, 0)
        }

        guard let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return (100, false, 100, 0, 0)
        }

        let level = (desc[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue ?? 100
        let maxCap = (desc[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue ?? 100
        let isCharging = (desc[kIOPSIsChargingKey] as? NSNumber)?.boolValue ?? false
        let cycleCount = (desc["CycleCount"] as? NSNumber)?.intValue ?? 0
        let temperature = (desc["Temperature"] as? NSNumber)?.doubleValue ?? 0

        return (level, isCharging, maxCap, cycleCount, temperature > 0 ? temperature / 10.0 : 0)
    }

    // MARK: - Memory Detail

    private func getMemoryDetail() -> (pressure: Double, app: Double, wired: Double, compressed: Double) {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size) / 4

        guard withUnsafeMutablePointer(to: &stats, {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }) == KERN_SUCCESS else { return (0, 0, 0, 0) }

        let pageSize = Double(vm_kernel_page_size)
        let app = Double(stats.active_count) * pageSize / 1_073_741_824
        let wired = Double(stats.wire_count) * pageSize / 1_073_741_824
        let compressed = Double(stats.compressor_page_count) * pageSize / 1_073_741_824

        // 内存压力 = (active + wired + compressor) / total
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let pressure = total > 0 ? (Double(stats.active_count + stats.wire_count + stats.compressor_page_count) * pageSize / total * 100) : 0

        return (pressure, app, wired, compressed)
    }

    // MARK: - Local IP

    private func getLocalIP() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "" }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)

            if name == "en0" || name == "en1" {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: hostname)
                if !ip.isEmpty && ip != "0.0.0.0" { return ip }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }
        return ""
    }

    // MARK: - Private Methods

    private func update() {
        let cpuDetail = monitor.cpuUsageDetail()
        let (memUsed, memTotal) = monitor.memoryUsage()
        let (diskUsed, diskTotal) = monitor.diskUsage()
        let memDetail = getMemoryDetail()
        let battery = getBatteryInfo()
        let netSpeed = getNetworkSpeed()

        stats = SystemStats(
            cpuUsage: cpuDetail.total,
            cpuSystem: cpuDetail.system,
            cpuUser: cpuDetail.user,
            cpuIdle: cpuDetail.idle,
            memoryUsed: memUsed,
            memoryTotal: memTotal,
            memoryPercent: memTotal > 0 ? memUsed / memTotal * 100 : 0,
            memoryPressure: memDetail.pressure,
            memoryApp: memDetail.app,
            memoryWired: memDetail.wired,
            memoryCompressed: memDetail.compressed,
            diskUsed: diskUsed,
            diskTotal: diskTotal,
            diskPercent: diskTotal > 0 ? diskUsed / diskTotal * 100 : 0,
            batteryLevel: battery.level,
            batteryIsCharging: battery.isCharging,
            batteryMaxCapacity: battery.maxCapacity,
            batteryCycleCount: battery.cycleCount,
            batteryTemperature: battery.temperature,
            networkConnected: currentNetworkConnected,
            networkType: currentNetworkType,
            networkInterface: currentNetworkConnected ? currentNetworkType.rawValue : "",
            localIP: getLocalIP(),
            uploadSpeed: netSpeed.upload,
            downloadSpeed: netSpeed.download
        )
    }
}

// MARK: - System Monitor Protocol

protocol SystemMonitorProtocol {
    func cpuUsageDetail() -> (total: Double, system: Double, user: Double, idle: Double)
    func cpuUsage() -> Double
    func memoryUsage() -> (used: Double, total: Double)
    func diskUsage() -> (used: Double, total: Double)
}

// MARK: - Default System Monitor

struct DefaultSystemMonitor: SystemMonitorProtocol {
    func cpuUsage() -> Double {
        cpuUsageDetail().total
    }

    func cpuUsageDetail() -> (total: Double, system: Double, user: Double, idle: Double) {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), HOST_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo) == KERN_SUCCESS,
              let cpuInfo = cpuInfo else { return (0, 0, 0, 100) }

        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(numCPUInfo) * MemoryLayout<integer_t>.size))
        }

        var totalSystem: Double = 0
        var totalUser: Double = 0
        var totalIdle: Double = 0
        var totalNice: Double = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
            totalSystem += system
            totalUser += user
            totalIdle += idle
            totalNice += nice
        }

        let total = totalSystem + totalUser + totalIdle + totalNice
        guard total > 0 else { return (0, 0, 0, 100) }

        let n = Double(numCPUs)
        return (
            (totalUser + totalSystem + totalNice) / total * 100,
            totalSystem / total * 100,
            totalUser / total * 100,
            totalIdle / total * 100
        )
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
