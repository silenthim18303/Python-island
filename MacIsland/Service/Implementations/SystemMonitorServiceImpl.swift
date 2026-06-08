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

        // 订阅系统监控数据变化，同步小组件
        $stats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.updateWidgetData(stats)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateWidgetData(_ stats: SystemStats) {
        WidgetDataManager.shared.updateSystemMonitor(
            cpuUsage: stats.cpuUsage,
            cpuTemperature: stats.cpuTemperature,
            cpuCoreCount: stats.cpuCoreCount,
            memoryUsage: stats.memoryPercent,
            memoryUsed: stats.memoryUsed,
            memoryTotal: stats.memoryTotal,
            diskUsage: stats.diskPercent,
            diskUsed: stats.diskUsed,
            diskTotal: stats.diskTotal,
            batteryLevel: Int(stats.batteryLevel),
            batteryCharging: stats.batteryIsCharging,
            networkConnected: stats.networkConnected,
            networkType: stats.networkType.rawValue,
            localIP: stats.localIP,
            uploadSpeed: stats.uploadSpeed,
            downloadSpeed: stats.downloadSpeed
        )
    }

    func startMonitoring() {
        // 系统资源轮询（0.5秒间隔，快速响应）
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.update() }
        }
        // 初始调用也在主线程，确保线程一致
        DispatchQueue.main.async { self.update() }

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
        // 使用 IOKit Registry API 直接读取，避免 NSSecureCoding XPC 警告
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMPowerSource"))
        guard service != IO_OBJECT_NULL else { return (100, false, 100, 0, 0) }
        defer { IOObjectRelease(service) }

        let level = IORegistryEntryCreateCFProperty(service, "CurrentCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Double ?? 100
        let maxCap = IORegistryEntryCreateCFProperty(service, "MaxCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Double ?? 100
        let isCharging = (IORegistryEntryCreateCFProperty(service, "IsCharging" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool) ?? false
        let cycleCount = (IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int) ?? 0
        let temperature = (IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Double) ?? 0

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
            cpuCoreCount: monitor.cpuCoreCount(),
            cpuTemperature: monitor.cpuTemperature(),
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
    func cpuCoreCount() -> Int
    func cpuTemperature() -> Double
    func memoryUsage() -> (used: Double, total: Double)
    func diskUsage() -> (used: Double, total: Double)
}

// MARK: - Default System Monitor

final class DefaultSystemMonitor: SystemMonitorProtocol {
    private var prevTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var lastCheckTime: Date?

    func cpuUsage() -> Double {
        cpuUsageDetail().total
    }

    func cpuUsageDetail() -> (total: Double, system: Double, user: Double, idle: Double) {
        guard let ticks = readCPUTicks() else {
            return (0, 0, 0, 100)
        }

        let now = Date()
        guard let prev = prevTicks, let lastTime = lastCheckTime,
              now.timeIntervalSince(lastTime) > 0.05 else {
            // 首次或间隔太短：快速双读
            prevTicks = ticks
            lastCheckTime = now
            Thread.sleep(forTimeInterval: 0.05)
            guard let t2 = readCPUTicks() else { return (0, 0, 0, 100) }
            let du = t2.user - ticks.user, ds = t2.system - ticks.system
            let di = t2.idle - ticks.idle, dn = t2.nice - ticks.nice
            let dt = du + ds + di + dn
            prevTicks = t2; lastCheckTime = Date()
            guard dt > 0 else { return (0, 0, 0, 100) }
            return (Double(du+ds+dn)/Double(dt)*100, Double(ds)/Double(dt)*100, Double(du)/Double(dt)*100, Double(di)/Double(dt)*100)
        }

        let du = ticks.user - prev.user, ds = ticks.system - prev.system
        let di = ticks.idle - prev.idle, dn = ticks.nice - prev.nice
        let dt = du + ds + di + dn
        prevTicks = ticks; lastCheckTime = now
        guard dt > 0 else { return (0, 0, 0, 100) }
        let total = Double(du+ds+dn)/Double(dt)*100
        print("[CPU] \(String(format: "%.1f", total))% (sys=\(String(format: "%.1f", Double(ds)/Double(dt)*100)) user=\(String(format: "%.1f", Double(du)/Double(dt)*100)))")
        return (total, Double(ds)/Double(dt)*100, Double(du)/Double(dt)*100, Double(di)/Double(dt)*100)
    }

    /// 读取 CPU ticks（host_statistics + HOST_CPU_LOAD_INFO，兼容 Apple Silicon）
    private func readCPUTicks() -> (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var data = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &data) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return (
            user: UInt64(data.cpu_ticks.0),     // CPU_STATE_USER
            system: UInt64(data.cpu_ticks.1),   // CPU_STATE_SYSTEM
            idle: UInt64(data.cpu_ticks.2),     // CPU_STATE_IDLE
            nice: UInt64(data.cpu_ticks.3)      // CPU_STATE_NICE
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

    func cpuCoreCount() -> Int {
        var size: size_t = 0
        var len: size_t = MemoryLayout<size_t>.size
        guard sysctlbyname("hw.ncpu", &size, &len, nil, 0) == 0 else { return 0 }
        return Int(size)
    }

    func cpuTemperature() -> Double {
        // 通过 IOKit SMC 读取 CPU 温度传感器（TC0P = CPU Proximity）
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }

        let key: [UInt8] = [0x54, 0x43, 0x30, 0x50] // "TC0P"
        let inputStruct: [UInt8] = [
            0x00, 0x08, 0x00, 0x00,  // command type: read
            0x00, 0x00, 0x00, 0x00,
            0x53, 0x47, 0x4E, 0x45,  // "SGNE" - signature
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ]

        // 简化方案：直接通过 IORegistryEntry 读取已知的温度 key
        // 如果 SMC 方法不可用，返回 0
        var input = inputStruct
        var output = [UInt8](repeating: 0, count: 40)
        var outputSize = output.count

        let result = IOConnectCallStructMethod(
            service,
            UInt32(2), // kSMCReadKey
            &input,
            input.count,
            &output,
            &outputSize
        )

        guard result == KERN_SUCCESS, outputSize >= 20 else { return 0 }

        // 温度值在 output 的 bytes 12..15（float32 little-endian）
        let tempBytes = output[12..<16]
        let temp = tempBytes.withUnsafeBytes { $0.load(as: Float32.self) }
        return temp > 0 && temp < 150 ? Double(temp) : 0
    }
}
