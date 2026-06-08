//
//  ConnectionManager.swift
//  MacIslandCompanion
//
//  Created by GeminiMortal on 2026/6/8.
//

import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// 连接管理器 - 负责与 MacIsland 的通信
@MainActor
class ConnectionManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isConnected = false
    @Published var isSearching = false
    @Published var connectionStatus = "未连接"
    @Published var macName = ""
    @Published var errorMessage: String?

    // MARK: - MultipeerConnectivity

    private let serviceType = "macisland-svc"
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?
    private var advertiser: MCNearbyServiceAdvertiser?

    // MARK: - Timer

    private var pingTimer: Timer?
    private var batteryTimer: Timer?

    override init() {
        super.init()
        setupMultipeer()
    }

    // MARK: - Setup

    private func setupMultipeer() {
        let deviceName = UIDevice.current.name
        peerID = MCPeerID(displayName: deviceName)

        guard let peerID = peerID else { return }

        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
    }

    // MARK: - Public Methods

    /// 开始搜索 MacIsland 服务
    func startSearching() {
        guard !isSearching else { return }

        isSearching = true
        connectionStatus = "搜索中..."
        errorMessage = nil

        browser?.startBrowsingForPeers()
    }

    /// 停止搜索
    func stopSearching() {
        isSearching = false
        browser?.stopBrowsingForPeers()
    }

    /// 断开连接
    func disconnect() {
        session?.disconnect()
        isConnected = false
        connectionStatus = "已断开"
        macName = ""
        stopTimers()
    }

    /// 发送通知到 Mac
    func sendNotification(title: String, body: String, appName: String) {
        guard isConnected else { return }

        let notification: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "body": body,
            "appName": appName,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        sendMessage(type: "notification", payload: notification)
    }

    // MARK: - Private Methods

    private func sendMessage(type: String, payload: Any) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }

        let message: [String: Any] = [
            "type": type,
            "payload": payload,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "messageID": UUID().uuidString
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Failed to send message: \(error)")
        }
    }

    private func sendDeviceInfo() {
        let deviceInfo: [String: Any] = [
            "name": UIDevice.current.name,
            "model": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion,
            "deviceType": "iphone"
        ]

        sendMessage(type: "deviceInfo", payload: deviceInfo)
    }

    private func sendBatteryStatus() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let isCharging = UIDevice.current.batteryState == .charging

        let batteryStatus: [String: Any] = [
            "level": Double(batteryLevel),
            "isCharging": isCharging,
            "isLowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled
        ]

        sendMessage(type: "batteryStatus", payload: batteryStatus)
    }

    private func startTimers() {
        // 每 30 秒发送电池状态
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendBatteryStatus()
            }
        }

        // 每 15 秒发送心跳
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendMessage(type: "ping", payload: [:])
            }
        }
    }

    private func stopTimers() {
        batteryTimer?.invalidate()
        batteryTimer = nil
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "ping":
            sendMessage(type: "pong", payload: [:])
        case "pong":
            break
        default:
            print("Received message: \(type)")
        }
    }
}

// MARK: - MCSessionDelegate

extension ConnectionManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.isConnected = true
                self.isSearching = false
                self.connectionStatus = "已连接"
                self.macName = peerID.displayName
                self.errorMessage = nil
                self.browser?.stopBrowsingForPeers()

                // 发送设备信息和电池状态
                self.sendDeviceInfo()
                self.sendBatteryStatus()
                self.startTimers()

            case .connecting:
                self.connectionStatus = "连接中..."

            case .notConnected:
                if self.isConnected {
                    self.isConnected = false
                    self.connectionStatus = "连接断开"
                    self.macName = ""
                    self.stopTimers()
                }

            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            do {
                if let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.handleMessage(message)
                }
            } catch {
                print("Failed to decode message: \(error)")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            print("Found peer: \(peerID.displayName)")

            // 检查是否是 MacIsland 服务
            if info?["app"] == "macisland" {
                self.connectionStatus = "发现 MacIsland: \(peerID.displayName)"
                // 自动邀请连接
                browser.invitePeer(peerID, to: self.session!, withContext: nil, timeout: 30)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            print("Lost peer: \(peerID.displayName)")
            if self.macName == peerID.displayName {
                self.isConnected = false
                self.connectionStatus = "连接断开"
                self.macName = ""
                self.stopTimers()
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.isSearching = false
            self.connectionStatus = "搜索失败"
            self.errorMessage = error.localizedDescription
        }
    }
}
