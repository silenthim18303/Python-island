//
//  MusicService.swift
//  MacIsland
//
//  音乐服务 — 检测 + 状态 + 控制
//  三源协同：分布式通知 + CGWindowList + AppleScript
//

import SwiftUI
import Combine
import AppKit
import CoreGraphics
import CoreAudio
import AudioToolbox

// MARK: - Music Service

/// 统一音乐服务 — 检测播放器、维护播放状态、提供播放控制
final class MusicService: MusicServiceProtocol, ObservableObject {
    @Published private(set) var info: MusicInfo = .empty
    @Published private(set) var hasMedia = false

    var canSeek: Bool { _appleScriptAuthorized }

    // MARK: - Detection State

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 3.0
    private var lastPollTime: Date = .distantPast
    private var activePlayerBundleID: String?
    /// 播放器进程存活检测定时器
    private var playerAliveTimer: Timer?
    /// 播放器进程消失连续次数（容错：临时查不到不立即清除）
    private var playerDeadCount = 0

    // AppleScript
    private var _appleScriptAuthorized = false
    private var appleScriptPollTimer: Timer?
    private var lastAppleScriptPollTime: Date = .distantPast

    // 系统音量
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var interpolationTimer: Timer?
    private var lastElapsed: TimeInterval = 0
    private var lastUpdateTime: Date = .now
    private var lastTitle: String = ""

    /// 已知播放器 bundleID 集合（用于快速查找）
    private let knownPlayerBundleIDs: Set<String> = [
        "com.apple.Music", "com.spotify.client",
        "com.tencent.QQMusicMac", "com.kugou.mac", "com.kuwo.mac",
        "com.netease.cloudmusic", "com.netease.163music",
        "com.luna.music", "com.migu.music", "com.qianqian.player",
        "com.tidal.desktop", "com.deezer.desktop", "com.amazon.music",
        "com.coppertino.Vox",
    ]

    /// bundleID -> AppleScript 应用名映射
    private let appleScriptNames: [String: String] = [
        "com.apple.Music": "Music",
        "com.spotify.client": "Spotify",
        "com.coppertino.Vox": "Vox",
    ]

    /// 播放器特定分布式通知名称
    private let playerDistributedNotifications: [Notification.Name] = [
        Notification.Name("com.apple.iTunes.playerInfo"),
        Notification.Name("com.apple.Music.playerInfo"),
        Notification.Name("com.spotify.client.PlaybackStateChanged"),
        Notification.Name("com.kugou.mac.playerInfo"),
        Notification.Name("com.tencent.qqmusic.mac.playerStateChanged"),
        Notification.Name("com.netease.163music.mac.playerStateChanged"),
        Notification.Name("com.netease.163music.playerStateChanged"),
        Notification.Name("com.netease.163music.playerInfo"),
        Notification.Name("com.kuwo.mac.playerInfo"),
        Notification.Name("com.kuwo.mac.playerStateChanged"),
        Notification.Name("com.luna.music.playerInfo"),
        Notification.Name("com.luna.music.playerStateChanged"),
    ]

    // 窗口标题黑名单
    private let titleBlacklist = [
        "登录", "设置", "偏好", "发现", "我的", "歌单", "排行榜",
        "下载", "关注", "消息", "动态", "会员", "商城",
        "迷你", "Mini", "歌词", "Lyrics", "均衡器", "Equalizer",
        "正在播放", "Now Playing", "播放列表", "Playlist",
        "搜索", "Search", "电台", "Radio", "播客", "Podcast",
        "MV", "视频", "Video", "直播", "Live",
        "Settings", "Login", "Sign", "Browse", "Library",
        "Home", "Explore", "Queue", "History", "Liked", "Albums",
        "Artists", "Genres", "Podcasts", "Downloads",
    ]

    private let windowTitleAppNames: Set<String> = [
        "Music", "Spotify", "Vox",
        "音乐", "QQ音乐", "酷狗音乐", "酷我音乐",
        "网易云音乐", "汽水音乐", "咪咕音乐", "千千音乐",
        "Tidal", "Deezer", "Amazon Music",
    ]

    // MARK: - Lifecycle

    func startMonitoring() {
        // 1. 分布式通知监听 —— 捕获 Apple Music / Spotify 等的实时通知
        startDistributedNotificationListening()

        // 2. NSWorkspace 激活事件
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // 3. CGWindowList 定时轮询（兜底，用于网易云等无通知播放器）
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollWindowTitles()
        }

        // 4. 检查 AppleScript 权限
        checkAppleScriptPermission()

        // 5. 插值定时器
        startInterpolation()

        // 6. 系统音量
        startVolumeListener()

        // 7. 播放器进程存活检测（每 1 秒检查一次，连续 2 次失败 = 2 秒判定退出）
        playerAliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPlayerAlive()
        }

        // 启动后立即检测一次所有已知播放器
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.detectRunningPlayers()
        }

        // 启动后 3 秒再检测一次（等待 AppleScript 权限检查完成）
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, self.info == .empty else { return }
            self.detectRunningPlayers()
        }
    }

    func stopMonitoring() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(
            self, name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        pollTimer?.invalidate()
        pollTimer = nil
        appleScriptPollTimer?.invalidate()
        appleScriptPollTimer = nil
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        playerAliveTimer?.invalidate()
        playerAliveTimer = nil
        stopVolumeListener()
    }

    // MARK: - Distributed Notification Listening

    /// 监听所有播放器的分布式通知
    private func startDistributedNotificationListening() {
        // 监听所有分布式通知（不限定 name/object，由回调过滤）
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDistributedNotification(_:)),
            name: nil,
            object: nil
        )
        print("[MusicService] 开始监听分布式通知")
    }

    /// 处理分布式通知
    @objc private func handleDistributedNotification(_ notification: Notification) {
        let rawName = notification.name.rawValue

        // 跳过 MacIsland 自身的通知
        guard !rawName.contains("MacIsland") else { return }

        // 1. 通过通知名称匹配已知播放器
        if let bundleID = bundleIDForNotificationName(rawName) {
            activePlayerBundleID = bundleID
            processNotificationUserInfo(notification.userInfo, bundleID: bundleID)
            return
        }

        // 2. 通过 notification.object (bundleID) 匹配
        if let bundleID = notification.object as? String,
           knownPlayerBundleIDs.contains(bundleID) {
            activePlayerBundleID = bundleID
            processNotificationUserInfo(notification.userInfo, bundleID: bundleID)
            return
        }
    }

    /// 根据通知名称反查 bundleID
    private func bundleIDForNotificationName(_ name: String) -> String? {
        switch name {
        case "com.apple.iTunes.playerInfo", "com.apple.Music.playerInfo":
            return "com.apple.Music"
        case "com.spotify.client.PlaybackStateChanged":
            return "com.spotify.client"
        case "com.tencent.qqmusic.mac.playerStateChanged":
            return "com.tencent.QQMusicMac"
        case "com.kugou.mac.playerInfo":
            return "com.kugou.mac"
        case "com.kuwo.mac.playerInfo", "com.kuwo.mac.playerStateChanged":
            return "com.kuwo.mac"
        case "com.netease.163music.mac.playerStateChanged",
             "com.netease.163music.playerStateChanged",
             "com.netease.163music.playerInfo":
            return "com.netease.cloudmusic"
        case "com.luna.music.playerInfo", "com.luna.music.playerStateChanged":
            return "com.luna.music"
        default:
            return nil
        }
    }

    /// 从通知 userInfo 提取歌曲信息
    private func processNotificationUserInfo(_ userInfo: [AnyHashable: Any]?, bundleID: String) {
        guard let userInfo = userInfo, !userInfo.isEmpty else {
            // 无 userInfo（网易云等常见），触发 CGWindowList 兜底
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.pollWindowTitles()
            }
            return
        }

        // 尝试 MediaRemote 标准键名（Apple Music / Spotify）
        let title = (userInfo["kMRMediaRemoteNowPlayingInfoTitle"] as? String)
            ?? (userInfo["Name"] as? String)
            ?? (userInfo["Track Name"] as? String)
        let artist = (userInfo["kMRMediaRemoteNowPlayingInfoArtist"] as? String)
            ?? (userInfo["Artist"] as? String) ?? ""
        let album = (userInfo["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)
            ?? (userInfo["Album"] as? String) ?? ""

        let duration: TimeInterval = {
            if let d = userInfo["kMRMediaRemoteNowPlayingInfoDuration"] as? TimeInterval { return d }
            if let d = userInfo["Total Time"] as? TimeInterval { return d / 1000.0 }
            if let d = userInfo["Total Time"] as? Int { return TimeInterval(d) / 1000.0 }
            return 0
        }()

        let elapsed: TimeInterval = {
            if let e = userInfo["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? TimeInterval { return e }
            if let e = userInfo["Elapsed Time"] as? TimeInterval { return e / 1000.0 }
            if let e = userInfo["Position"] as? TimeInterval { return e }
            return 0
        }()

        let isPlaying: Bool = {
            if let rate = userInfo["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double { return rate > 0 }
            if let state = userInfo["Player State"] as? String { return state.lowercased().contains("playing") }
            if let state = userInfo["Player State"] as? Int { return state == 1 }
            return false
        }()

        var artwork: NSImage?
        if let data = userInfo["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
            artwork = NSImage(data: data)
        }

        guard let title = title, !title.isEmpty else { return }

        print("[MusicService] 通知检测到: \(title) — \(artist) (playing: \(isPlaying))")

        let result = MusicInfo(
            title: title, artist: artist, album: album,
            duration: duration, elapsedTime: elapsed,
            isPlaying: isPlaying, artwork: artwork
        )
        updateInfo(result)
    }

    // MARK: - NSWorkspace Activation

    @objc private func handleAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        if knownPlayerBundleIDs.contains(bundleID) {
            activePlayerBundleID = bundleID
            pollWindowTitles()
            // Apple Music/Spotify 立即尝试 AppleScript
            if bundleID == "com.apple.Music" || bundleID == "com.spotify.client" {
                pollAppleScript()
            }
        }
    }

    /// 启动后检测所有已运行的音乐播放器
    private func detectRunningPlayers() {
        for bundleID in knownPlayerBundleIDs {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !apps.isEmpty {
                activePlayerBundleID = bundleID
                if bundleID == "com.apple.Music" || bundleID == "com.spotify.client" {
                    pollAppleScript()
                }
                pollWindowTitles()
                break
            }
        }
    }

    /// 检查当前活跃播放器进程是否仍在运行
    /// 连续 2 次查不到才判定退出（4 秒，防止临时查询失败导致误清除）
    private func checkPlayerAlive() {
        guard hasMedia, let bundleID = activePlayerBundleID else { return }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if apps.isEmpty {
            playerDeadCount += 1
            if playerDeadCount >= 2 {
                print("[MusicService] 播放器 \(bundleID) 已退出，清除媒体状态")
                hasMedia = false
                lastTitle = ""
                info = .empty
                playerDeadCount = 0
            }
        } else {
            playerDeadCount = 0
        }
    }

    // MARK: - CGWindowList Polling

    private func pollWindowTitles() {
        guard Date().timeIntervalSince(lastPollTime) >= 2.0 else { return }
        lastPollTime = .now

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.doPollWindowTitles()
        }
    }

    private func doPollWindowTitles() {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        // 优先检测已知激活的播放器
        if let bundleID = activePlayerBundleID,
           let result = searchWindowForPlayer(bundleID: bundleID, windowList: windowList) {
            DispatchQueue.main.async { [weak self] in
                self?.updateInfo(result)
            }
            return
        }

        // 兜底：遍历所有已知播放器
        for bundleID in knownPlayerBundleIDs {
            if let result = searchWindowForPlayer(bundleID: bundleID, windowList: windowList) {
                DispatchQueue.main.async { [weak self] in
                    self?.activePlayerBundleID = bundleID
                    self?.updateInfo(result)
                }
                return
            }
        }
    }

    private func searchWindowForPlayer(bundleID: String, windowList: [[String: Any]]) -> MusicInfo? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return nil
        }
        let pid = app.processIdentifier

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid else { continue }

            let title = window[kCGWindowName as String] as? String ?? ""
            guard !title.isEmpty else { continue }
            if windowTitleAppNames.contains(title) { continue }
            if titleBlacklist.contains(where: { title.contains($0) }) { continue }

            if let result = parseWindowTitle(title) {
                print("[MusicService] CGWindowList 检测到: \(result.title) — \(result.artist)")
                return result
            }
        }
        return nil
    }

    private func parseWindowTitle(_ title: String) -> MusicInfo? {
        let cleaned = title
            .replacingOccurrences(of: "▶ ", with: "")
            .replacingOccurrences(of: "⏸ ", with: "")
            .replacingOccurrences(of: "♪ ", with: "")
            .replacingOccurrences(of: "♫ ", with: "")
            .replacingOccurrences(of: "🎵 ", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard cleaned.count >= 2 else { return nil }
        let isPlaying = !title.contains("⏸")

        let separators = [" - ", " — ", " – ", " ‒ ", " · "]
        for sep in separators {
            guard let range = cleaned.range(of: sep) else { continue }
            let left = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(cleaned[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard left.count >= 2, right.count >= 2 else { continue }

            if left.count <= 8 && right.count > left.count {
                return MusicInfo(title: right, artist: left, album: "",
                                 duration: 0, elapsedTime: 0, isPlaying: isPlaying, artwork: nil)
            }
            return MusicInfo(title: left, artist: right, album: "",
                             duration: 0, elapsedTime: 0, isPlaying: isPlaying, artwork: nil)
        }
        return nil
    }

    // MARK: - AppleScript

    private func checkAppleScriptPermission() {
        Task {
            let script = """
            tell application "Music"
                if player state is not stopped then
                    return name of current track
                end if
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                _appleScriptAuthorized = (error == nil)
            }
            if _appleScriptAuthorized {
                print("[MusicService] AppleScript 权限可用")
                await MainActor.run {
                    self.startAppleScriptPolling()
                }
            } else {
                print("[MusicService] AppleScript 权限不可用，使用 CGWindowList 检测")
            }
        }
    }

    private func startAppleScriptPolling() {
        appleScriptPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollAppleScript()
        }
    }

    private func pollAppleScript() {
        guard _appleScriptAuthorized else { return }
        guard Date().timeIntervalSince(lastAppleScriptPollTime) >= 0.8 else { return }
        lastAppleScriptPollTime = .now

        Task {
            if let result = await queryAppleScript(appName: "Music") {
                DispatchQueue.main.async { [weak self] in
                    self?.activePlayerBundleID = "com.apple.Music"
                    self?.updateInfo(result)
                }
                return
            }
            if let result = await queryAppleScript(appName: "Spotify", durationInMs: true) {
                DispatchQueue.main.async { [weak self] in
                    self?.activePlayerBundleID = "com.spotify.client"
                    self?.updateInfo(result)
                }
            }
        }
    }

    private func queryAppleScript(appName: String, durationInMs: Bool = false) async -> MusicInfo? {
        let script = """
        tell application "\(appName)"
            if player state is not stopped then
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set trackDuration to duration of current track
                set trackPosition to player position
                set isPlaying to (player state is playing)
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & (trackDuration as text) & "|||" & (trackPosition as text) & "|||" & (isPlaying as text)
            end if
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let output = appleScript.executeAndReturnError(&error)
        if let err = error {
            print("[MusicService] AppleScript 错误 (\(appName)): \(err)")
            return nil
        }

        let parts = (output.stringValue ?? "").components(separatedBy: "|||")
        guard parts.count >= 6 else {
            // 播放器暂停/停止时输出为空，属于正常行为，不打印错误
            return nil
        }

        let title = parts[0].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }

        print("[MusicService] AppleScript 检测到: \(title) — \(parts[1].trimmingCharacters(in: .whitespaces))")
        return MusicInfo(
            title: title,
            artist: parts[1].trimmingCharacters(in: .whitespaces),
            album: parts[2].trimmingCharacters(in: .whitespaces),
            duration: (Double(parts[3]) ?? 0) / (durationInMs ? 1000.0 : 1.0),
            elapsedTime: Double(parts[4]) ?? 0,
            isPlaying: parts[5].trimmingCharacters(in: .whitespaces).lowercased() == "true",
            artwork: nil
        )
    }

    // MARK: - State Update

    private func updateInfo(_ newInfo: MusicInfo) {
        let titleChanged = newInfo.title != lastTitle
        let playingChanged = newInfo.isPlaying != info.isPlaying

        if titleChanged {
            lastTitle = newInfo.title
            lastElapsed = newInfo.elapsedTime
            lastUpdateTime = .now
            info = newInfo
            hasMedia = true
            playerDeadCount = 0
            // 缺少封面或时长时，在线补充
            if newInfo.artwork == nil || newInfo.duration == 0 {
                enrichMetadata(title: newInfo.title, artist: newInfo.artist)
            }
        } else if playingChanged {
            lastElapsed = newInfo.elapsedTime
            lastUpdateTime = .now
            info = newInfo
            hasMedia = true
            playerDeadCount = 0
        } else {
            // 进度更新 — 校准插值基准点
            let now = Date()
            let interpolatedElapsed = lastElapsed + now.timeIntervalSince(lastUpdateTime)
            let drift = newInfo.elapsedTime - interpolatedElapsed

            if abs(drift) > 1.0 {
                lastElapsed = newInfo.elapsedTime
                lastUpdateTime = now
            } else if drift > 0.3 {
                lastElapsed = newInfo.elapsedTime
                lastUpdateTime = now
            }

            // 仅标题/艺术家/播放状态变化时才更新 info（避免插值定时器触发无意义的 UI 刷新）
            let meaningfulChange = newInfo.title != info.title
                || newInfo.artist != info.artist
                || newInfo.album != info.album
                || newInfo.duration != info.duration
                || newInfo.isPlaying != info.isPlaying
                || newInfo.artwork != nil && newInfo.artwork != info.artwork

            if meaningfulChange {
                info = newInfo
            }
            if !newInfo.title.isEmpty { hasMedia = true }
        }
    }

    // MARK: - Playback Controls

    func togglePlay() {
        if let bundleID = activePlayerBundleID, let appName = appleScriptNames[bundleID] {
            let command = info.isPlaying ? "pause" : "play"
            Task { _ = await executeAppleScript("tell application \"\(appName)\"\n\(command)\nend tell") }
            // 乐观更新
            info = MusicInfo(title: info.title, artist: info.artist, album: info.album,
                             duration: info.duration, elapsedTime: info.elapsedTime,
                             isPlaying: !info.isPlaying, artwork: info.artwork)
            return
        }
        sendMediaKey(0x10)
        info = MusicInfo(title: info.title, artist: info.artist, album: info.album,
                         duration: info.duration, elapsedTime: info.elapsedTime,
                         isPlaying: !info.isPlaying, artwork: info.artwork)
    }

    func nextTrack() {
        if let bundleID = activePlayerBundleID, let appName = appleScriptNames[bundleID] {
            Task { _ = await executeAppleScript("tell application \"\(appName)\"\nnext track\nend tell") }
            return
        }
        sendMediaKey(0x12)
    }

    func previousTrack() {
        if let bundleID = activePlayerBundleID, let appName = appleScriptNames[bundleID] {
            Task { _ = await executeAppleScript("tell application \"\(appName)\"\nprevious track\nend tell") }
            return
        }
        sendMediaKey(0x11)
    }

    func setVolume(_ volume: Float) {
        setSystemVolume(volume)
    }

    func seek(to time: TimeInterval) {
        guard let bundleID = activePlayerBundleID, let appName = appleScriptNames[bundleID] else { return }
        let script = """
        tell application "\(appName)"
            if player state is playing then
                set player position to \(time)
            end if
        end tell
        """
        Task { _ = await executeAppleScript(script) }
    }

    // MARK: - Interpolation

    private func startInterpolation() {
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.hasMedia, self.info.isPlaying, self.info.duration > 0 else { return }
            let delta = Date().timeIntervalSince(self.lastUpdateTime)
            let interpolated = self.lastElapsed + delta
            guard interpolated <= self.info.duration else { return }
            self.info = MusicInfo(
                title: self.info.title, artist: self.info.artist, album: self.info.album,
                duration: self.info.duration, elapsedTime: interpolated,
                isPlaying: self.info.isPlaying, artwork: self.info.artwork
            )
        }
    }

    // MARK: - Metadata Enrichment

    private var metadataTask: Task<Void, Never>?

    private func enrichMetadata(title: String, artist: String) {
        metadataTask?.cancel()
        metadataTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let query = "\(title) \(artist)"
            guard let searchURL = URL(string: "https://music.163.com/api/search/get/web") else { return }

            var request = URLRequest(url: searchURL)
            request.httpMethod = "POST"
            request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&limit=1".data(using: .utf8)
            request.timeoutInterval = 5

            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let result = json["result"] as? [String: Any],
                      let songs = result["songs"] as? [[String: Any]],
                      let song = songs.first else { return }

                guard !Task.isCancelled else { return }

                let durationMs = song["duration"] as? TimeInterval ?? 0
                let duration = durationMs / 1000.0

                var artworkURL: String?
                if let album = song["album"] as? [String: Any] {
                    artworkURL = album["picUrl"] as? String
                }

                var artwork: NSImage?
                if let urlString = artworkURL, let url = URL(string: urlString) {
                    let (imgData, _) = try await URLSession.shared.data(from: url)
                    artwork = NSImage(data: imgData)
                }

                guard !Task.isCancelled else { return }

                self.info = MusicInfo(
                    title: self.info.title, artist: self.info.artist, album: self.info.album,
                    duration: duration > 0 ? duration : self.info.duration,
                    elapsedTime: self.info.elapsedTime,
                    isPlaying: self.info.isPlaying,
                    artwork: artwork ?? self.info.artwork
                )
            } catch {}
        }
    }

    // MARK: - System Volume

    private func getDefaultOutputDeviceID() -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectSystemObject)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func getSystemVolume() -> Float {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return 0.5 }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : 0.5
    }

    private func setSystemVolume(_ volume: Float) {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }

    private func startVolumeListener() {
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            let _ = self.getSystemVolume()
        }
        volumeListenerBlock = block
        AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
    }

    private func stopVolumeListener() {
        guard let block = volumeListenerBlock else { return }
        let deviceID = getDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
        volumeListenerBlock = nil
    }

    // MARK: - Helpers

    private func sendMediaKey(_ keyCode: CGKeyCode) {
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private func executeAppleScript(_ source: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(returning: false)
                    return
                }
                _ = script.executeAndReturnError(&error)
                continuation.resume(returning: error == nil)
            }
        }
    }
}
