//
//  ClipboardServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Clipboard URL Detection Mode

/// 剪贴板 URL 检测模式
/// - TODO: 预留配置项，待接入设置 UI（当前检测固定走 http/https 提取）
enum ClipboardUrlDetectMode: String {
    case httpsOnly = "https-only"
    case httpHttps = "http-https"
    case domainOnly = "domain-only"
}

// MARK: - Detected URL

/// 一条已检测到的剪贴板链接（携带抓取到的网页标题）
struct DetectedURL: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let title: String

    static func == (lhs: DetectedURL, rhs: DetectedURL) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - Clipboard Service Protocol

/// 剪贴板链接检测服务 — 轮询剪贴板提取 URL 并抓取标题
protocol ClipboardServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    var detectedURLs: [DetectedURL] { get }
    func startMonitoring()
    func stopMonitoring()
}
