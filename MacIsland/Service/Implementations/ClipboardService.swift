//
//  ClipboardService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit
import Combine

/// 剪贴板 URL 监听服务
final class ClipboardService: ClipboardServiceProtocol, ObservableObject {
    @Published private(set) var detectedURLs: [DetectedURL] = []
    var isEnabled: Bool = true

    private var pollTimer: Timer?
    private var lastClipboardText: String = ""
    /// 用户自定义域名黑名单 — TODO: 预留，待接入设置 UI / 持久化（当前无写入入口，恒为空）
    private var blacklist: Set<String> = []
    private var onNotification: ((String, String) -> Void)?
    private let session: URLSession

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    func setNotificationHandler(_ handler: @escaping (String, String) -> Void) {
        self.onNotification = handler
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard pollTimer == nil else { return }
        // Initial read to suppress existing clipboard content
        lastClipboardText = NSPasteboard.general.string(forType: .string) ?? ""
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Polling

    private func poll() {
        guard isEnabled else { return }
        guard let current = NSPasteboard.general.string(forType: .string),
              !current.isEmpty,
              current != lastClipboardText else { return }

        lastClipboardText = current

        let urls = extractUrls(from: current)
            .filter { !isBlacklisted($0) }
            .uniqued()

        guard !urls.isEmpty else { return }

        // Fetch title for first URL, then notify
        Task {
            let title = await fetchPageTitle(urls[0])
            let detected = urls.map { DetectedURL(url: $0, title: title.isEmpty ? hostname($0) ?? $0 : title) }

            await MainActor.run {
                self.detectedURLs = detected
                let displayTitle = detected.first?.title ?? urls[0]
                let truncated = String(displayTitle.prefix(48))
                self.onNotification?("🔗 链接检测", truncated)
            }
        }
    }

    // MARK: - URL Extraction

    private func extractUrls(from text: String) -> [String] {
        let pattern = "https?://[^\\s<>\"{}|\\\\^`\\[\\]]+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return matches.compactMap { match -> String? in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r])
        }
    }

    // MARK: - Blacklist

    /// 命中用户域名黑名单则跳过该链接（精确匹配或子域匹配）。
    /// 注：当前 `blacklist` 无写入入口恒为空，此判断暂为预留逻辑。
    private func isBlacklisted(_ urlString: String) -> Bool {
        guard let host = hostname(urlString) else { return false }
        let lower = host.lowercased()
        if blacklist.contains(lower) { return true }
        for domain in blacklist {
            if lower.hasSuffix(".\(domain)") { return true }
        }
        return false
    }

    private func hostname(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return url.host
    }

    // MARK: - Title Fetching

    /// 仅允许抓取公网主机的标题，拦截 localhost / 私有网段 / 链路本地（含云元数据端点），避免 SSRF
    private func isPublicHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }

        // 主机名形式的本地地址
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return false
        }

        // IPv6 回环(::1) / 链路本地(fe80:) / 唯一本地地址 ULA(fc/fd 前缀)
        if host == "::1" || host.hasPrefix("fe80:") || host.hasPrefix("fc") || host.hasPrefix("fd") {
            return false
        }

        // IPv4 点分十进制——校验保留网段
        let octets = host.split(separator: ".")
        if octets.count == 4, let a = Int(octets[0]), let b = Int(octets[1]),
           octets[2].allSatisfy(\.isNumber), octets[3].allSatisfy(\.isNumber) {
            switch a {
            case 0, 10, 127: return false            // 本网络 / 私有 A 类 / 回环
            case 169 where b == 254: return false    // 链路本地（含 169.254.169.254 元数据端点）
            case 172 where (16...31).contains(b): return false  // 私有 B 类
            case 192 where b == 168: return false    // 私有 C 类
            default: break
            }
        }

        return true
    }

    private func fetchPageTitle(_ urlString: String) async -> String {
        guard let url = URL(string: urlString), isPublicHost(url.host) else { return "" }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        request.setValue("bytes=0-8191", forHTTPHeaderField: "Range")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let contentType = http.value(forHTTPHeaderField: "Content-Type"),
                  (contentType.contains("text/html") || contentType.contains("text/plain")),
                  let html = String(data: data.prefix(8192), encoding: .utf8) else {
                return ""
            }

            // Extract <title>
            let pattern = "<title[^>]*>(.*?)</title>"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(match.range(at: 1), in: html) else {
                return ""
            }
            return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return ""
        }
    }
}

// MARK: - Array Unique Extension

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
