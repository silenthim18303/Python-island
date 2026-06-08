//
//  PhoneServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation
import Network
import Combine

/// 设备配对服务 - 通过 Bonjour (WiFi) 接收手机/平板等设备的通知和状态
@MainActor
final class PhoneServiceImpl: ObservableObject, DeviceServiceProtocol {
    @Published private(set) var isListening: Bool = false
    @Published private(set) var connectedDevice: ConnectedDeviceInfo? = nil
    @Published private(set) var deviceBattery: DeviceBatteryStatus? = nil
    @Published private(set) var connectionState: DeviceConnectionState = .idle

    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.macisland.device-service")
    private var pingTimer: Timer?

    /// 通知回调
    var onNotification: ((String, String) -> Void)?

    // MARK: - Public Methods

    func startListening() {
        guard !isListening else { return }

        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try NWListener(using: params)
            listener.service = NWListener.Service(
                name: "MacIsland",
                type: "_macisland._tcp"
            )

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            self.listener = listener
            listener.start(queue: queue)
            connectionState = .advertising
        } catch {
            connectionState = .error
            print("[DeviceService] Failed to start listener: \(error)")
        }
    }

    func stopListening() {
        pingTimer?.invalidate()
        pingTimer = nil
        activeConnection?.cancel()
        activeConnection = nil
        listener?.cancel()
        listener = nil
        isListening = false
        connectionState = .idle
        connectedDevice = nil
        deviceBattery = nil
    }

    func disconnect() {
        activeConnection?.cancel()
        activeConnection = nil
        connectedDevice = nil
        deviceBattery = nil
        connectionState = .disconnected
    }

    // MARK: - Listener State

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            connectionState = .advertising
        case .failed(let error):
            isListening = false
            connectionState = .error
            print("[DeviceService] Listener failed: \(error)")
        case .cancelled:
            isListening = false
            connectionState = .idle
        default:
            break
        }
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        // 只允许一个连接
        if activeConnection != nil {
            connection.cancel()
            return
        }

        connectionState = .connecting
        activeConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionState(state)
            }
        }

        connection.start(queue: queue)
        receiveNextMessage(on: connection)
        startPingTimer()
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionState = .connected
        case .failed(_):
            connectionState = .disconnected
            cleanupConnection()
        case .cancelled:
            connectionState = .disconnected
            cleanupConnection()
        default:
            break
        }
    }

    // MARK: - Message Framing (Length-Prefix)

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let headerData = data, headerData.count == 4 else {
                if isComplete {
                    Task { @MainActor in
                        self?.cleanupConnection()
                    }
                }
                return
            }

            let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length < 1_048_576 else {
                self.receiveNextMessage(on: connection)
                return
            }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payloadData, _, _, _ in
                guard let self = self, let payload = payloadData else { return }
                Task { @MainActor in
                    self.handleReceivedPayload(payload)
                }
                self.receiveNextMessage(on: connection)
            }
        }
    }

    private func send(_ message: DeviceMessage) {
        guard let connection = activeConnection else { return }
        do {
            let jsonPayload = try JSONEncoder().encode(message)
            var length = UInt32(jsonPayload.count).bigEndian
            var data = Data(bytes: &length, count: 4)
            data.append(jsonPayload)
            connection.send(content: data, completion: .contentProcessed { _ in })
        } catch {
            print("[DeviceService] Failed to encode message: \(error)")
        }
    }

    // MARK: - Message Dispatch

    private func handleReceivedPayload(_ data: Data) {
        guard let message = try? JSONDecoder().decode(DeviceMessage.self, from: data) else {
            print("[DeviceService] Failed to decode message")
            return
        }

        switch message.type {
        case .notification:
            if let notification = try? JSONDecoder().decode(DeviceNotification.self, from: message.payload) {
                let deviceName = connectedDevice?.deviceType.displayName ?? "设备"
                onNotification?("[\(deviceName)] \(notification.appName)", notification.body)
            }

        case .batteryStatus:
            if let battery = try? JSONDecoder().decode(DeviceBatteryStatus.self, from: message.payload) {
                deviceBattery = battery
            }

        case .deviceInfo:
            if let device = try? JSONDecoder().decode(ConnectedDeviceInfo.self, from: message.payload) {
                connectedDevice = device
                print("[DeviceService] Device connected: \(device.name) (\(device.deviceType.displayName))")
            }

        case .ping:
            let pong = DeviceMessage(type: .pong, payload: Data(), timestamp: Date(), messageID: UUID())
            send(pong)

        case .pong:
            break
        }
    }

    // MARK: - Keep-Alive

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.connectionState == .connected else { return }
                let ping = DeviceMessage(type: .ping, payload: Data(), timestamp: Date(), messageID: UUID())
                self.send(ping)
            }
        }
    }

    private func cleanupConnection() {
        pingTimer?.invalidate()
        pingTimer = nil
        activeConnection?.stateUpdateHandler = nil
        activeConnection = nil
        connectedDevice = nil
        deviceBattery = nil
    }
}
