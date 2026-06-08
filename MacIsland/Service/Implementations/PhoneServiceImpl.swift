//
//  PhoneServiceImpl.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation
import Network
import MultipeerConnectivity
import Combine

/// 设备配对服务 - 支持 WiFi、蓝牙、热点等多种连接方式
@MainActor
final class PhoneServiceImpl: NSObject, ObservableObject, DeviceServiceProtocol {
    @Published private(set) var isListening: Bool = false
    @Published private(set) var connectedDevice: ConnectedDeviceInfo? = nil
    @Published private(set) var deviceBattery: DeviceBatteryStatus? = nil
    @Published private(set) var connectionState: DeviceConnectionState = .idle
    @Published private(set) var connectionType: ConnectionType = .unknown

    // MARK: - Network Framework (WiFi/Bonjour)

    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private let networkQueue = DispatchQueue(label: "com.macisland.network-service")

    // MARK: - MultipeerConnectivity (Bluetooth/WiFi Direct/Hotspot)

    private let serviceType = "macisland-svc"
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Common

    private var pingTimer: Timer?
    var onNotification: ((String, String) -> Void)?

    override init() {
        super.init()
        setupMultipeer()
    }

    // MARK: - Multipeer Setup

    private func setupMultipeer() {
        peerID = MCPeerID(displayName: Host.current().localizedName ?? "MacIsland")
        guard let peerID = peerID else { return }

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["app": "macisland"], serviceType: serviceType)
        advertiser?.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
    }

    // MARK: - Public Methods

    func startListening() {
        guard !isListening else { return }

        // 启动 Network Framework (WiFi/Bonjour)
        startNetworkListener()

        // 启动 MultipeerConnectivity (蓝牙/热点/WiFi Direct)
        advertiser?.startAdvertisingPeer()

        isListening = true
        connectionState = .advertising
    }

    func stopListening() {
        pingTimer?.invalidate()
        pingTimer = nil

        // 停止 Network Framework
        activeConnection?.cancel()
        activeConnection = nil
        listener?.cancel()
        listener = nil

        // 停止 MultipeerConnectivity
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        isListening = false
        connectionState = .idle
        connectedDevice = nil
        deviceBattery = nil
        connectionType = .unknown
    }

    func disconnect() {
        // 断开 Network Framework
        activeConnection?.cancel()
        activeConnection = nil

        // 断开 MultipeerConnectivity
        session?.disconnect()

        connectedDevice = nil
        deviceBattery = nil
        connectionState = .disconnected
        connectionType = .unknown
    }

    // MARK: - Network Framework (WiFi/Bonjour)

    private func startNetworkListener() {
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
                    self?.handleNetworkListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewNetworkConnection(connection)
                }
            }

            self.listener = listener
            listener.start(queue: networkQueue)
        } catch {
            print("[DeviceService] Failed to start network listener: \(error)")
        }
    }

    private func handleNetworkListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("[DeviceService] Network listener ready")
        case .failed(let error):
            print("[DeviceService] Network listener failed: \(error)")
        default:
            break
        }
    }

    private func handleNewNetworkConnection(_ connection: NWConnection) {
        if activeConnection != nil {
            connection.cancel()
            return
        }

        connectionState = .connecting
        connectionType = .wifi
        activeConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleNetworkConnectionState(state)
            }
        }

        connection.start(queue: networkQueue)
        receiveNextNetworkMessage(on: connection)
    }

    private func handleNetworkConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            connectionState = .connected
            startPingTimer()
        case .failed(_), .cancelled:
            cleanupNetworkConnection()
        default:
            break
        }
    }

    // MARK: - Network Message Framing

    private func receiveNextNetworkMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self = self, let headerData = data, headerData.count == 4 else {
                if isComplete {
                    Task { @MainActor in
                        self?.cleanupNetworkConnection()
                    }
                }
                return
            }

            let length = headerData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0, length < 1_048_576 else {
                self.receiveNextNetworkMessage(on: connection)
                return
            }

            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] payloadData, _, _, _ in
                guard let self = self, let payload = payloadData else { return }
                Task { @MainActor in
                    self.handleReceivedPayload(payload)
                }
                self.receiveNextNetworkMessage(on: connection)
            }
        }
    }

    private func sendNetworkMessage(_ message: DeviceMessage) {
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

    private func cleanupNetworkConnection() {
        pingTimer?.invalidate()
        pingTimer = nil
        activeConnection?.stateUpdateHandler = nil
        activeConnection = nil
        connectedDevice = nil
        deviceBattery = nil
        connectionState = .disconnected
        connectionType = .unknown
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
            if var device = try? JSONDecoder().decode(ConnectedDeviceInfo.self, from: message.payload) {
                device.connectionType = connectionType
                connectedDevice = device
                print("[DeviceService] Device connected: \(device.name) via \(connectionType.displayName)")
            }

        case .ping:
            let pong = DeviceMessage(type: .pong, payload: Data(), timestamp: Date(), messageID: UUID())
            sendMessage(pong)

        case .pong:
            break
        }
    }

    private func sendMessage(_ message: DeviceMessage) {
        // 根据连接类型选择发送方式
        if connectionType == .wifi {
            sendNetworkMessage(message)
        } else {
            sendMultipeerMessage(message)
        }
    }

    // MARK: - Multipeer Message

    private func sendMultipeerMessage(_ message: DeviceMessage) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[DeviceService] Failed to send multipeer message: \(error)")
        }
    }

    // MARK: - Keep-Alive

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.connectionState == .connected else { return }
                let ping = DeviceMessage(type: .ping, payload: Data(), timestamp: Date(), messageID: UUID())
                self.sendMessage(ping)
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension PhoneServiceImpl: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.connectionState = .connected
                self.connectionType = self.detectConnectionType(for: peerID)
                self.startPingTimer()
                print("[DeviceService] Multipeer connected: \(peerID.displayName) via \(self.connectionType.displayName)")
            case .connecting:
                self.connectionState = .connecting
            case .notConnected:
                if self.connectionState == .connected {
                    self.cleanupMultipeerConnection()
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.handleReceivedPayload(data)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    private func cleanupMultipeerConnection() {
        pingTimer?.invalidate()
        pingTimer = nil
        connectedDevice = nil
        deviceBattery = nil
        connectionState = .disconnected
        connectionType = .unknown
    }

    /// 检测连接类型
    private func detectConnectionType(for peerID: MCPeerID) -> ConnectionType {
        // MultipeerConnectivity 支持蓝牙、WiFi、热点等多种连接
        // 实际连接类型由系统自动选择，这里返回通用类型
        // 可以通过检查网络接口来进一步区分
        return .bluetooth // 默认使用蓝牙，因为 Multipeer 优先使用蓝牙
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension PhoneServiceImpl: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受连接
        Task { @MainActor in
            print("[DeviceService] Received invitation from: \(peerID.displayName)")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            print("[DeviceService] Failed to start advertising: \(error)")
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension PhoneServiceImpl: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // 发现设备时自动邀请连接
        Task { @MainActor in
            print("[DeviceService] Found peer: \(peerID.displayName)")
            browser.invitePeer(peerID, to: self.session!, withContext: nil, timeout: 30)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            print("[DeviceService] Lost peer: \(peerID.displayName)")
        }
    }
}
