//
//  LyricsService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit
import Combine

/// Multi-provider lyrics service — inspired by eIsland's architecture
/// Supports: NetEase, QQ Music, Kugou, LRCLIB (fallback)
final class LyricsService: LyricsServiceProtocol, ObservableObject {
    @Published private(set) var currentLyrics: LyricsDocument = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private let session: URLSession
    private var lastFetchKey: String?

    // Provider definitions
    private enum Provider: String, CaseIterable {
        case netease = "NetEase"
        case qqmusic = "QQMusic"
        case kugou = "Kugou"
        case lrclib = "LRCLIB"
    }

    // Player bundle ID to provider mapping
    private let playerToProvider: [(bundleID: String, provider: Provider)] = [
        ("com.netease.163music", .netease),
        ("com.tencent.QQMusicMac", .qqmusic),
        ("com.kugou.mac", .kugou),
        ("com.apple.Music", .lrclib),
        ("com.spotify.client", .lrclib),
    ]

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    func fetchLyrics(title: String, artist: String, duration: TimeInterval) async {
        let cacheKey = "\(title)|\(artist)"
        guard cacheKey != lastFetchKey || currentLyrics == .empty else { return }

        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        defer { Task { @MainActor in isLoading = false } }

        // Detect provider based on running player
        let primaryProvider = detectProvider()
        print("[Lyrics] Fetching lyrics for \"\(title)\" by \(artist), provider: \(primaryProvider?.rawValue ?? "auto")")

        // 选源策略：把当前播放器对应的歌词源排到首位，其余作为兜底依次尝试；
        // 未识别到播放器时按 Provider 默认顺序全量尝试。
        let providers: [Provider] = {
            if let primary = primaryProvider {
                let others = Provider.allCases.filter { $0 != primary }
                return [primary] + others
            }
            return Provider.allCases
        }()

        for provider in providers {
            if let doc = await fetchFromProvider(provider, title: title, artist: artist, duration: duration) {
                print("[Lyrics] Success from \(provider.rawValue), \(doc.lines.count) lines")
                await MainActor.run {
                    self.currentLyrics = doc
                    self.lastFetchKey = cacheKey
                }
                return
            }
        }

        print("[Lyrics] All providers failed")
        await MainActor.run {
            self.currentLyrics = .empty
            self.lastError = "未找到歌词"
        }
    }

    func clearLyrics() {
        currentLyrics = .empty
        lastFetchKey = nil
        lastError = nil
    }

    // MARK: - Provider Detection

    /// 依据正在运行的播放器 App 的 bundleID 推断首选歌词源；
    /// 无匹配（如 Apple Music / 未知播放器）时返回 nil，调用方走全量 fallback。
    private func detectProvider() -> Provider? {
        for (bundleID, provider) in playerToProvider {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                return provider
            }
        }
        return nil
    }

    // MARK: - Provider Dispatch

    private func fetchFromProvider(_ provider: Provider, title: String, artist: String, duration: TimeInterval) async -> LyricsDocument? {
        switch provider {
        case .netease:
            return await fetchFromNetease(title: title, artist: artist)
        case .qqmusic:
            return await fetchFromQQMusic(title: title, artist: artist)
        case .kugou:
            return await fetchFromKugou(title: title, artist: artist)
        case .lrclib:
            return await fetchFromLRCLIB(title: title, artist: artist, duration: duration)
        }
    }

    // MARK: - NetEase (网易云音乐)

    private func fetchFromNetease(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"
        guard let searchURL = URL(string: "https://music.163.com/api/search/get/web") else { return nil }

        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&limit=5&offset=0".data(using: .utf8)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first,
                  let songId = firstSong["id"] as? Int else {
                return nil
            }

            // Fetch lyrics
            return await fetchNeteaseLyrics(songId: songId)
        } catch {
            print("[Lyrics] NetEase search error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchNeteaseLyrics(songId: Int) async -> LyricsDocument? {
        guard let url = URL(string: "https://interface3.music.163.com/api/song/lyric/v1") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "id=\(songId)&lv=-1&kv=-1&tv=-1".data(using: .utf8)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            // Try LRC format
            if let lrc = json["lrc"] as? [String: Any],
               let lyric = lrc["lyric"] as? String, !lyric.isEmpty {
                return parseLRC(lyric, source: "NetEase")
            }

            return nil
        } catch {
            print("[Lyrics] NetEase lyrics error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - QQ Music

    private func fetchFromQQMusic(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"

        // Search for song
        let searchPayload: [String: Any] = [
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": "5",
                    "page_num": "1",
                    "query": query,
                    "search_type": 0
                ] as [String: Any]
            ] as [String: Any]
        ]

        guard let searchURL = URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg") else { return nil }

        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: searchPayload)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let req1 = json["req_1"] as? [String: Any],
                  let data = req1["data"] as? [String: Any],
                  let body = data["body"] as? [String: Any],
                  let song = body["song"] as? [String: Any],
                  let list = song["list"] as? [[String: Any]],
                  let firstSong = list.first,
                  let mid = firstSong["mid"] as? String else {
                return nil
            }

            return await fetchQQMusicLyrics(mid: mid)
        } catch {
            print("[Lyrics] QQMusic search error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchQQMusicLyrics(mid: String) async -> LyricsDocument? {
        let callback = "MusicJsonCallback_lrc"
        var components = URLComponents(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")!
        components.queryItems = [
            URLQueryItem(name: "callback", value: callback),
            URLQueryItem(name: "pcachetime", value: String(Date().timeIntervalSince1970)),
            URLQueryItem(name: "songmid", value: mid),
            URLQueryItem(name: "g_tk", value: "5381"),
            URLQueryItem(name: "jsonpCallback", value: callback),
            URLQueryItem(name: "loginUin", value: "0"),
            URLQueryItem(name: "hostUin", value: "0"),
            URLQueryItem(name: "format", value: "jsonp"),
            URLQueryItem(name: "inCharset", value: "utf8"),
            URLQueryItem(name: "outCharset", value: "utf8"),
            URLQueryItem(name: "notice", value: "0"),
            URLQueryItem(name: "platform", value: "yqq"),
            URLQueryItem(name: "needNewCode", value: "0"),
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let rawText = String(data: data, encoding: .utf8) else { return nil }

            // Parse JSONP response
            let prefix = "\(callback)("
            guard rawText.hasPrefix(prefix) else { return nil }
            let jsonStr = String(rawText.dropFirst(prefix.count).dropLast())

            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let lyricB64 = json["lyric"] as? String else {
                return nil
            }

            // Base64 decode
            guard let decodedData = Data(base64Encoded: lyricB64),
                  let lyric = String(data: decodedData, encoding: .utf8) else {
                return nil
            }

            return parseLRC(lyric, source: "QQMusic")
        } catch {
            print("[Lyrics] QQMusic lyrics error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Kugou (酷狗音乐)

    private func fetchFromKugou(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"
        guard let searchURL = URL(string: "https://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&page=1&pagesize=5") else { return nil }

        var request = URLRequest(url: searchURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let data = json["data"] as? [String: Any],
                  let info = data["info"] as? [[String: Any]],
                  let firstSong = info.first,
                  let hash = firstSong["hash"] as? String else {
                return nil
            }

            return await fetchKugouLyrics(hash: hash)
        } catch {
            print("[Lyrics] Kugou search error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchKugouLyrics(hash: String) async -> LyricsDocument? {
        guard let url = URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=&duration=&hash=\(hash)&album_audio_id=") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let id = first["id"] as? String,
                  let accesskey = first["accesskey"] as? String else {
                return nil
            }

            return await fetchKugouLyricsContent(id: id, accesskey: accesskey)
        } catch {
            print("[Lyrics] Kugou lyrics search error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchKugouLyricsContent(id: String, accesskey: String) async -> LyricsDocument? {
        guard let url = URL(string: "https://lyrics.kugou.com/download?ver=1&client=pc&id=\(id)&accesskey=\(accesskey)&fmt=lrc&charset=utf8") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? String else {
                return nil
            }

            // Base64 decode
            guard let decodedData = Data(base64Encoded: content),
                  let lyric = String(data: decodedData, encoding: .utf8) else {
                return nil
            }

            return parseLRC(lyric, source: "Kugou")
        } catch {
            print("[Lyrics] Kugou lyrics content error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - LRCLIB

    private func fetchFromLRCLIB(title: String, artist: String, duration: TimeInterval) async -> LyricsDocument? {
        // Try exact match first
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]

        if let url = components.url {
            var request = URLRequest(url: url)
            request.setValue("MacIsland/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 8

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let doc = parseLRCLIBResponse(data) {
                return doc
            }
        }

        // Fallback to search
        components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("MacIsland/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }

            let results = try JSONDecoder().decode([LRCLIBResult].self, from: data)
            for result in results {
                if let synced = result.syncedLyrics, !synced.isEmpty {
                    return parseLRC(synced, source: "LRCLIB")
                }
            }
            if let plain = results.first?.plainLyrics, !plain.isEmpty {
                return parsePlainLyrics(plain, source: "LRCLIB")
            }
            return nil
        } catch {
            print("[Lyrics] LRCLIB search error: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseLRCLIBResponse(_ data: Data) -> LyricsDocument? {
        guard let result = try? JSONDecoder().decode(LRCLIBResult.self, from: data) else { return nil }
        if let synced = result.syncedLyrics, !synced.isEmpty {
            return parseLRC(synced, source: "LRCLIB")
        }
        if let plain = result.plainLyrics, !plain.isEmpty {
            return parsePlainLyrics(plain, source: "LRCLIB")
        }
        return nil
    }

    // MARK: - LRC Parser

    func parseLRC(_ lrc: String, source: String) -> LyricsDocument {
        var lines: [LrcLine] = []

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)$"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
                continue
            }

            let minRange = Range(match.range(at: 1), in: trimmed)!
            let secRange = Range(match.range(at: 2), in: trimmed)!
            let minutes = Double(trimmed[minRange]) ?? 0
            let seconds = Double(trimmed[secRange]) ?? 0

            var ms: Double = 0
            if let msRange = Range(match.range(at: 3), in: trimmed) {
                let msStr = trimmed[msRange]
                let padded = String(msStr).padding(toLength: 3, withPad: "0", startingAt: 0)
                ms = Double(padded) ?? 0
            }

            let time = minutes * 60 + seconds + ms / 1000.0

            let textRange = Range(match.range(at: 4), in: trimmed)!
            let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)

            if !text.isEmpty {
                lines.append(LrcLine(time: time, text: text))
            }
        }

        lines.sort { $0.time < $1.time }
        return LyricsDocument(lines: lines, source: source)
    }

    private func parsePlainLyrics(_ text: String, source: String) -> LyricsDocument {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let interval = 4.0
        let lrcLines = lines.enumerated().map { i, line in
            LrcLine(time: TimeInterval(i) * interval, text: line)
        }

        return LyricsDocument(lines: lrcLines, source: source)
    }
}

// MARK: - LRCLIB Response Model

private struct LRCLIBResult: Codable {
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
}
