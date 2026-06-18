//
//  LyricsService.swift
//  MacIsland
//
//  四源歌词服务 — 网易云/QQ音乐/酷狗/LRCLIB
//  并行获取 + 磁盘缓存 + 模糊匹配
//

import Foundation
import Combine
import CryptoKit

// MARK: - Lyrics Service

/// 四源歌词服务
final class LyricsService: LyricsServiceProtocol, ObservableObject {
    @Published private(set) var currentLyrics: LyricsDocument = .empty
    @Published private(set) var isLoading = false

    private let session: URLSession
    private var lastFetchKey: String?
    private var currentFetchTask: Task<Void, Never>?
    private var pendingRequests: [String: Task<LyricsDocument?, Never>] = [:]

    // MARK: - Cache

    private static let cacheDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LyricsCache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private static let maxCacheCount = 200

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Public API

    func fetchLyrics(title: String, artist: String, duration: TimeInterval) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty, title.count >= 2 else { return }
        let cacheKey = makeCacheKey(title: title, artist: artist, duration: duration)
        guard cacheKey != lastFetchKey || currentLyrics == .empty else { return }

        // 取消之前的请求
        currentFetchTask?.cancel()
        currentFetchTask = nil

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // 1. 磁盘缓存
        if let cached = loadFromDiskCache(key: cacheKey) {
            await MainActor.run {
                self.currentLyrics = cached
                self.lastFetchKey = cacheKey
            }
            return
        }

        // 2. 并行获取（带取消）
        let task = Task<LyricsDocument?, Never> {
            await fetchParallel(title: title, artist: artist, duration: duration)
        }
        currentFetchTask = Task { @MainActor [weak self] in
            if let doc = await task.value {
                self?.saveToDiskCache(key: cacheKey, doc: doc)
                self?.currentLyrics = doc
                self?.lastFetchKey = cacheKey
            } else {
                self?.currentLyrics = .empty
            }
        }
        await currentFetchTask?.value
    }

    func clearLyrics() {
        currentFetchTask?.cancel()
        currentFetchTask = nil
        currentLyrics = .empty
        lastFetchKey = nil
    }

    // MARK: - Parallel Fetch

    private func fetchParallel(title: String, artist: String, duration: TimeInterval) async -> LyricsDocument? {
        await withTaskGroup(of: LyricsDocument?.self) { group in
            // 按优先级添加任务（LRCLIB 最可靠，放最后）
            group.addTask { await self.fetchFromNetease(title: title, artist: artist) }
            group.addTask { await self.fetchFromQQMusic(title: title, artist: artist) }
            group.addTask { await self.fetchFromKugou(title: title, artist: artist) }
            group.addTask { await self.fetchFromLRCLIB(title: title, artist: artist, duration: duration) }

            for await result in group {
                if Task.isCancelled { break }
                if let doc = result, !doc.lines.isEmpty {
                    group.cancelAll()
                    print("[LyricsService] 获取到歌词: \(doc.source), \(doc.lines.count) 行")
                    return doc
                }
            }
            print("[LyricsService] 所有源均未获取到歌词")
            return nil
        }
    }

    // MARK: - Cache Key

    private func makeCacheKey(title: String, artist: String, duration: TimeInterval) -> String {
        let durationRounded = Int(duration / 10) * 10
        return "\(title)|\(artist)|\(durationRounded)"
    }

    // MARK: - NetEase

    private func fetchFromNetease(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"
        guard let searchURL = URL(string: "https://music.163.com/api/search/get/web") else { return nil }

        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&limit=5".data(using: .utf8)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]] else {
                print("[LyricsService] NetEase: 搜索结果格式错误")
                return nil
            }

            guard let bestSong = pickBestSong(songs, title: title, artist: artist),
                  let songId = bestSong["id"] as? Int else {
                print("[LyricsService] NetEase: 未找到匹配歌曲")
                return nil
            }

            return await fetchNeteaseLyrics(songId: songId)
        } catch {
            print("[LyricsService] NetEase 请求失败: \(error.localizedDescription)")
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
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lrc = json["lrc"] as? [String: Any],
                  let lyric = lrc["lyric"] as? String, !lyric.isEmpty else {
                print("[LyricsService] NetEase: 歌词内容为空")
                return nil
            }
            return parseLRC(lyric, source: "NetEase")
        } catch {
            print("[LyricsService] NetEase 歌词请求失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - QQ Music

    private func fetchFromQQMusic(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"
        let payload: [String: Any] = [
            "req_1": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": ["num_per_page": "5", "page_num": "1", "query": query, "search_type": 0] as [String: Any]
            ] as [String: Any]
        ]

        guard let searchURL = URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg") else { return nil }
        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let req1 = json["req_1"] as? [String: Any],
                  let dataDict = req1["data"] as? [String: Any],
                  let body = dataDict["body"] as? [String: Any],
                  let song = body["song"] as? [String: Any],
                  let list = song["list"] as? [[String: Any]] else {
                print("[LyricsService] QQMusic: 搜索结果格式错误")
                return nil
            }

            guard let bestSong = pickBestSong(list, title: title, artist: artist),
                  let mid = bestSong["mid"] as? String else {
                print("[LyricsService] QQMusic: 未找到匹配歌曲")
                return nil
            }

            return await fetchQQMusicLyrics(mid: mid)
        } catch {
            print("[LyricsService] QQMusic 请求失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchQQMusicLyrics(mid: String) async -> LyricsDocument? {
        let callback = "MusicJsonCallback_lrc"
        var components = URLComponents(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg")!
        components.queryItems = [
            URLQueryItem(name: "callback", value: callback),
            URLQueryItem(name: "songmid", value: mid),
            URLQueryItem(name: "format", value: "jsonp"),
            URLQueryItem(name: "nobase64", value: "1"),
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let rawText = String(data: data, encoding: .utf8) else {
                print("[LyricsService] QQMusic: 响应数据无法解码")
                return nil
            }
            let prefix = "\(callback)("
            guard rawText.hasPrefix(prefix) else {
                print("[LyricsService] QQMusic: JSONP 格式错误")
                return nil
            }
            let jsonStr = String(rawText.dropFirst(prefix.count).dropLast())
            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let lyric = json["lyric"] as? String else {
                print("[LyricsService] QQMusic: 歌词内容为空")
                return nil
            }

            return parseLRC(lyric, source: "QQMusic")
        } catch {
            print("[LyricsService] QQMusic 歌词请求失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Kugou

    private func fetchFromKugou(title: String, artist: String) async -> LyricsDocument? {
        let query = "\(title) \(artist)"
        guard let searchURL = URL(string: "https://mobilecdn.kugou.com/api/v3/search/song?format=json&keyword=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&page=1&pagesize=5") else { return nil }

        var request = URLRequest(url: searchURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let info = dataDict["info"] as? [[String: Any]] else {
                print("[LyricsService] Kugou: 搜索结果格式错误")
                return nil
            }

            guard let bestSong = pickBestSong(info, title: title, artist: artist),
                  let hash = bestSong["hash"] as? String else {
                print("[LyricsService] Kugou: 未找到匹配歌曲")
                return nil
            }

            return await fetchKugouLyrics(hash: hash)
        } catch {
            print("[LyricsService] Kugou 请求失败: \(error.localizedDescription)")
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
                print("[LyricsService] Kugou: 未找到歌词候选")
                return nil
            }

            return await fetchKugouLyricsContent(id: id, accesskey: accesskey)
        } catch {
            print("[LyricsService] Kugou 歌词搜索失败: \(error.localizedDescription)")
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
                print("[LyricsService] Kugou: 歌词内容为空")
                return nil
            }
            guard let decodedData = Data(base64Encoded: content),
                  let lyric = String(data: decodedData, encoding: .utf8) else {
                print("[LyricsService] Kugou: Base64 解码失败")
                return nil
            }
            return parseLRC(lyric, source: "Kugou")
        } catch {
            print("[LyricsService] Kugou 歌词下载失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - LRCLIB

    private func fetchFromLRCLIB(title: String, artist: String, duration: TimeInterval) async -> LyricsDocument? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration))),
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

        // 回退到搜索
        components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("MacIsland/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                print("[LyricsService] LRCLIB: HTTP 状态码错误")
                return nil
            }

            let results = try JSONDecoder().decode([LRCLIBResult].self, from: data)

            if let best = pickBestLRCLIBResult(results, title: title, artist: artist, duration: duration) {
                if let synced = best.syncedLyrics, !synced.isEmpty { return parseLRC(synced, source: "LRCLIB") }
                if let plain = best.plainLyrics, !plain.isEmpty { return parsePlainLyrics(plain, source: "LRCLIB") }
            }

            for result in results {
                if let synced = result.syncedLyrics, !synced.isEmpty { return parseLRC(synced, source: "LRCLIB") }
            }
            if let plain = results.first?.plainLyrics, !plain.isEmpty { return parsePlainLyrics(plain, source: "LRCLIB") }
            return nil
        } catch {
            print("[LyricsService] LRCLIB 请求失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseLRCLIBResponse(_ data: Data) -> LyricsDocument? {
        guard let result = try? JSONDecoder().decode(LRCLIBResult.self, from: data) else { return nil }
        if let synced = result.syncedLyrics, !synced.isEmpty { return parseLRC(synced, source: "LRCLIB") }
        if let plain = result.plainLyrics, !plain.isEmpty { return parsePlainLyrics(plain, source: "LRCLIB") }
        return nil
    }

    // MARK: - Fuzzy Match

    private func pickBestSong(_ songs: [[String: Any]], title: String, artist: String) -> [String: Any]? {
        guard !songs.isEmpty else { return nil }
        if songs.count == 1 { return songs.first }

        var bestScore = Double.infinity
        var bestSong = songs.first!

        for song in songs {
            let songTitle = extractString(song["name"])
            let songArtist = extractArtistName(song["artists"] ?? song["singer"])

            let titleScore = levenshteinDistance(title.lowercased(), songTitle.lowercased())
            let artistScore = levenshteinDistance(artist.lowercased(), songArtist.lowercased())
            let totalScore = Double(titleScore) * 2.0 + Double(artistScore)

            if totalScore < bestScore {
                bestScore = totalScore
                bestSong = song
            }
        }
        return bestSong
    }

    private func pickBestLRCLIBResult(_ results: [LRCLIBResult], title: String, artist: String, duration: TimeInterval) -> LRCLIBResult? {
        guard !results.isEmpty else { return nil }
        if results.count == 1 { return results.first }

        var bestScore = Double.infinity
        var bestResult = results.first!

        for result in results {
            let rTitle = result.trackName ?? ""
            let rArtist = result.artistName ?? ""
            let rDuration = result.duration ?? 0

            let titleScore = Double(levenshteinDistance(title.lowercased(), rTitle.lowercased()))
            let artistScore = Double(levenshteinDistance(artist.lowercased(), rArtist.lowercased()))
            let durationScore = abs(rDuration - duration) / 10.0
            let totalScore = titleScore * 2.0 + artistScore + durationScore

            if totalScore < bestScore {
                bestScore = totalScore
                bestResult = result
            }
        }
        return bestResult
    }

    private func extractString(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let arr = value as? [[String: Any]], let first = arr.first {
            return first["name"] as? String ?? ""
        }
        return ""
    }

    private func extractArtistName(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let arr = value as? [[String: Any]] {
            return arr.compactMap { $0["name"] as? String }.joined(separator: ", ")
        }
        return ""
    }

    private func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let sChars = Array(s), tChars = Array(t)
        let m = sChars.count, n = tChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if sChars[i - 1] == tChars[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + 1)
                }
            }
        }
        return dp[m][n]
    }

    // MARK: - Disk Cache

    private func loadFromDiskCache(key: String) -> LyricsDocument? {
        let hashed = Self.cacheHash(key)
        let fileURL = Self.cacheDir.appendingPathComponent("\(hashed).json")
        guard let data = try? Data(contentsOf: fileURL),
              let cached = try? JSONDecoder().decode(CachedLyrics.self, from: data) else { return nil }
        return cached.toDocument()
    }

    private func saveToDiskCache(key: String, doc: LyricsDocument) {
        let hashed = Self.cacheHash(key)
        let fileURL = Self.cacheDir.appendingPathComponent("\(hashed).json")
        let cached = CachedLyrics(lines: doc.lines.map { CachedLyrics.CachedLrcLine(time: $0.time, text: $0.text) }, source: doc.source)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: fileURL)
        Self.evictIfNeeded()
    }

    private static func evictIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: [.contentAccessDateKey], options: .skipsHiddenFiles
        ) else { return }
        guard files.count > maxCacheCount else { return }
        let sorted = files.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return lhsDate < rhsDate
        }
        for file in sorted.prefix(files.count - maxCacheCount) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func cacheHash(_ key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    // MARK: - LRC Parser

    func parseLRC(_ lrc: String, source: String) -> LyricsDocument {
        var lines: [LrcLine] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)$"#

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                  match.numberOfRanges >= 5 else { continue }

            guard let minRange = Range(match.range(at: 1), in: trimmed),
                  let secRange = Range(match.range(at: 2), in: trimmed) else { continue }

            let minutes = Double(trimmed[minRange]) ?? 0
            let seconds = Double(trimmed[secRange]) ?? 0
            var ms: Double = 0
            if let msRange = Range(match.range(at: 3), in: trimmed) {
                let msStr = trimmed[msRange]
                let padded = String(msStr).padding(toLength: 3, withPad: "0", startingAt: 0)
                ms = Double(padded) ?? 0
            }

            let lineTime = minutes * 60 + seconds + ms / 1000.0
            guard let textRange = Range(match.range(at: 4), in: trimmed) else { continue }
            let content = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }

            lines.append(LrcLine(time: lineTime, text: content))
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

// MARK: - Cache Model

private struct CachedLyrics: Codable {
    let lines: [CachedLrcLine]
    let source: String

    struct CachedLrcLine: Codable {
        let time: TimeInterval
        let text: String
    }

    func toDocument() -> LyricsDocument {
        LyricsDocument(lines: lines.map { LrcLine(time: $0.time, text: $0.text) }, source: source)
    }
}

// MARK: - LRCLIB Model

private struct LRCLIBResult: Codable {
    let trackName: String?
    let artistName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
}
