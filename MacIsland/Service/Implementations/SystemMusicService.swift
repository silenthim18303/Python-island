//
//  SystemMusicService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine
import AppKit
import CoreGraphics

/// System music service — event-driven via distributed notifications + CGWindowList fallback
final class SystemMusicService: MusicServiceProtocol, ObservableObject {
    @Published private(set) var info: MediaPlaybackInfo = .empty
    @Published private(set) var hasMedia = false

    private var interpolationTimer: Timer?
    private var windowPollTimer: Timer?
    private var simulationTimer: Timer?
    private var lastElapsed: TimeInterval = 0
    private var lastUpdateTime: Date = .now
    private var lastTitle: String = ""
    private let mediaKeySender: MediaKeySenderProtocol

    #if DEBUG
    private var simulatedSongs: [NowPlayingResult] = []
    private var simulationIndex: Int = 0
    private(set) var isSimulating: Bool = false
    #endif

    // Player definitions
    private struct PlayerDef {
        let bundleID: String
        let displayName: String
    }

    private let players: [PlayerDef] = [
        PlayerDef(bundleID: "com.apple.Music",            displayName: "Music"),
        PlayerDef(bundleID: "com.spotify.client",          displayName: "Spotify"),
        PlayerDef(bundleID: "com.tencent.QQMusicMac",      displayName: "QQ音乐"),
        PlayerDef(bundleID: "com.kugou.mac",               displayName: "酷狗音乐"),
        PlayerDef(bundleID: "com.kuwo.mac",                displayName: "酷我音乐"),
        PlayerDef(bundleID: "com.netease.163music",        displayName: "网易云音乐"),
        PlayerDef(bundleID: "com.tencent.karaoke-mac",     displayName: "全民K歌"),
        PlayerDef(bundleID: "com.apple.MobileSMS",         displayName: ""),  // skip Messages
    ]

    // Notification names from various players
    private let notificationNames: [Notification.Name] = [
        Notification.Name("com.apple.iTunes.playerInfo"),
        Notification.Name("com.apple.Music.playerInfo"),
        Notification.Name("com.spotify.client.PlaybackStateChanged"),
        Notification.Name("com.kugou.mac.playerInfo"),
        Notification.Name("com.tencent.qqmusic.mac.playerStateChanged"),
        Notification.Name("com.netease.163music.mac.playerStateChanged"),
    ]

    // MediaRemote disabled on macOS 26+ — private API calls are blocked
    // Keeping notification name listeners for DistributedNotification-based detection

    // MARK: - Init

    init(mediaKeySender: MediaKeySenderProtocol = DefaultMediaKeySender()) {
        self.mediaKeySender = mediaKeySender
        // MediaRemote private API is blocked on macOS 26+ — no initialization needed
    }

    // MARK: - Monitoring

    func startMonitoring() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMULATE_NOW_PLAYING"] == "1" {
            print("[Music] DEBUG: Starting simulation mode")
            isSimulating = true
            startSimulation()
            startInterpolation()
            return
        }
        #endif

        // 1. MediaRemote disabled on macOS 26+ (private API blocked)
        // Listen for MediaRemote internal notifications via DistributedNotification only
        let mrNames = [
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
        ]
        for name in mrNames {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(handleMediaNotification(_:)),
                name: Notification.Name(name), object: nil
            )
        }

        // 3. Listen for player-specific notifications
        for name in notificationNames {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(handlePlayerNotification(_:)),
                name: name, object: nil
            )
        }

        // 4. CGWindowList fallback polling (every 5s, only when no notification data)
        windowPollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if !self.hasMedia { self.pollWindowTitles() }
        }

        startInterpolation()

        // Initial poll (CGWindowList only — MediaRemote disabled on macOS 26+)
        pollWindowTitles()
    }

    func stopMonitoring() {
        DistributedNotificationCenter.default().removeObserver(self)
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        windowPollTimer?.invalidate()
        windowPollTimer = nil
        #if DEBUG
        simulationTimer?.invalidate()
        simulationTimer = nil
        isSimulating = false
        #endif
    }

    // MARK: - Notification Handlers

    /// MediaRemote 通知占位处理 —— macOS 26+ 私有 API 已被禁用，无法取详细 NowPlaying 信息，
    /// 仅记录日志；实际曲目数据依赖播放器自身的分布式通知与 CGWindowList 兜底检测。
    @objc private func handleMediaNotification(_ notification: Notification) {
        print("[Music] MediaRemote notification: \(notification.name)")
    }

    @objc private func handlePlayerNotification(_ notification: Notification) {
        print("[Music] Player notification: \(notification.name)")

        guard let userInfo = notification.userInfo else {
            print("[Music] Notification has no userInfo")
            return
        }

        // Extract info — try standard keys first, then Music.app keys
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

        guard let title = title, !title.isEmpty else {
            print("[Music] Notification has no title, keys: \(Array(userInfo.keys))")
            return
        }

        print("[Music] From notification: \(title) — \(artist)")
        applyResult(NowPlayingResult(
            title: title, artist: artist, album: album,
            duration: duration, position: elapsed,
            isPlaying: isPlaying, artwork: artwork
        ))
    }

    // MARK: - CGWindowList Fallback

    private func pollWindowTitles() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            for player in self.players {
                guard !player.displayName.isEmpty else { continue }
                let running = NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID)
                guard let app = running.first else { continue }
                let pid = app.processIdentifier

                if let result = self.readWindowTitle(pid: pid, appName: player.displayName) {
                    print("[Music] CGWindowList: \(result.title) — \(result.artist)")
                    DispatchQueue.main.async { self.applyResult(result) }
                    return
                }
            }
        }
    }

    private func readWindowTitle(pid: pid_t, appName: String) -> NowPlayingResult? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid else { continue }

            guard let title = window[kCGWindowName as String] as? String,
                  !title.isEmpty else { continue }

            let blacklist = [
                "登录", "设置", "偏好", "发现", "我的", "歌单", "排行榜",
                "Settings", "Login", "Sign", "Browse", "Search", "Library",
                "下载", "关注", "消息", "动态", "会员", "商城",
                "迷你", "Mini", "歌词", "Lyrics", "均衡器", "Equalizer",
                "正在播放", "Now Playing", "播放列表", "Playlist",
            ]
            if blacklist.contains(where: { title.contains($0) }) { continue }

            if let result = parseWindowTitle(title, appName: appName) {
                return result
            }
        }

        return nil
    }

    private func parseWindowTitle(_ title: String, appName: String) -> NowPlayingResult? {
        let cleaned = title
            .replacingOccurrences(of: "▶ ", with: "")
            .replacingOccurrences(of: "⏸ ", with: "")
            .replacingOccurrences(of: "♪ ", with: "")
            .replacingOccurrences(of: "♫ ", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard cleaned.count >= 2 else { return nil }
        let isPlaying = !title.contains("⏸")

        // Player-specific parsing
        switch appName {
        case "Spotify":
            return parseSpotifyTitle(cleaned, isPlaying: isPlaying)
        case "Music":
            return parseMusicAppTitle(cleaned, isPlaying: isPlaying)
        default:
            return parseGenericTitle(cleaned, isPlaying: isPlaying)
        }
    }

    /// Spotify: "Song Title - Artist"
    private func parseSpotifyTitle(_ title: String, isPlaying: Bool) -> NowPlayingResult? {
        let separators = [" - ", " — ", " – ", " ‒ "]
        for sep in separators {
            if let range = title.range(of: sep) {
                let songTitle = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let artist = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard songTitle.count >= 2 else { continue }
                return NowPlayingResult(
                    title: songTitle, artist: artist, album: "",
                    duration: 0, position: 0, isPlaying: isPlaying, artwork: nil
                )
            }
        }
        guard title.count >= 2 else { return nil }
        return NowPlayingResult(
            title: title, artist: "", album: "",
            duration: 0, position: 0, isPlaying: isPlaying, artwork: nil
        )
    }

    /// Apple Music: "Song Title - Artist" or "Song Title"
    private func parseMusicAppTitle(_ title: String, isPlaying: Bool) -> NowPlayingResult? {
        return parseSpotifyTitle(title, isPlaying: isPlaying)
    }

    /// Generic: "Artist - Song Title" (Chinese players often use this format)
    private func parseGenericTitle(_ title: String, isPlaying: Bool) -> NowPlayingResult? {
        let separators = [" - ", " — ", " – ", " ‒ "]
        for sep in separators {
            if let range = title.range(of: sep) {
                let left = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                // Heuristic: if the left part looks like a short artist name, use "artist - title" format
                // Otherwise use "title - artist" format.
                // 阈值 8：经验值，中文歌手名通常 ≤8 字符，左短则判定为「歌手 - 歌名」。
                if left.count <= 8 && right.count >= 2 {
                    // Likely "Artist - Song"
                    return NowPlayingResult(
                        title: right, artist: left, album: "",
                        duration: 0, position: 0, isPlaying: isPlaying, artwork: nil
                    )
                } else if left.count >= 2 {
                    // Likely "Song - Artist"
                    return NowPlayingResult(
                        title: left, artist: right, album: "",
                        duration: 0, position: 0, isPlaying: isPlaying, artwork: nil
                    )
                }
            }
        }
        guard title.count >= 2 else { return nil }
        return NowPlayingResult(
            title: title, artist: "", album: "",
            duration: 0, position: 0, isPlaying: isPlaying, artwork: nil
        )
    }

    // MARK: - Apply Result

    private struct NowPlayingResult {
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
        let position: TimeInterval
        let isPlaying: Bool
        let artwork: NSImage?
    }

    private func applyResult(_ result: NowPlayingResult) {
        guard result.title != lastTitle || result.isPlaying != info.isPlaying else { return }
        lastTitle = result.title
        lastElapsed = result.position
        lastUpdateTime = .now
        info = MediaPlaybackInfo(
            title: result.title, artist: result.artist, album: result.album,
            isPlaying: result.isPlaying, duration: result.duration,
            elapsedTime: result.position,
            artwork: result.artwork ?? info.artwork,
            volume: info.volume, isShuffle: false, repeatMode: 0
        )
        hasMedia = true
    }

    // MARK: - Playback Controls

    func togglePlay() {
        #if DEBUG
        if isSimulating { simulateTogglePlay(); return }
        #endif
        mediaKeySender.sendPlayPause()
    }

    func nextTrack() {
        #if DEBUG
        if isSimulating { simulateNext(); return }
        #endif
        mediaKeySender.sendNextTrack()
    }

    func previousTrack() {
        #if DEBUG
        if isSimulating { simulatePrevious(); return }
        #endif
        mediaKeySender.sendPreviousTrack()
    }

    func setVolume(_ volume: Float) {
        let percent = Int(min(max(volume, 0), 1) * 100)
        runAppleScript("set volume output volume \(percent)")
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: info.isPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: volume, isShuffle: info.isShuffle, repeatMode: info.repeatMode
        )
    }

    func seek(to time: TimeInterval) {
        // Try AppleScript seek for Music.app
        let script = """
        tell application "Music"
            if player state is playing then
                set player position to \(time)
            end if
        end tell
        """
        runAppleScript(script)
    }

    func toggleShuffle() {
        let newShuffle = !info.isShuffle
        // Try Music.app AppleScript
        let script = """
        tell application "Music"
            set shuffle enabled to \(newShuffle)
        end tell
        """
        runAppleScript(script)
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: info.isPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: info.volume, isShuffle: newShuffle, repeatMode: info.repeatMode
        )
    }

    func cycleRepeat() {
        let newMode = (info.repeatMode + 1) % 3
        let modeString: String
        switch newMode {
        case 0: modeString = "off"
        case 1: modeString = "all"
        case 2: modeString = "one"
        default: modeString = "off"
        }
        // Try Music.app AppleScript
        let script = """
        tell application "Music"
            set song repeat to \(modeString)
        end tell
        """
        runAppleScript(script)
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: info.isPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: info.volume, isShuffle: info.isShuffle, repeatMode: newMode
        )
    }

    // MARK: - AppleScript Helper

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return }
            script.executeAndReturnError(&error)
            if let err = error {
                let code = err["NSAppleScriptErrorNumber"] as? Int ?? 0
                if code != -1700 && code != -1728 && code != -600 {
                    print("[Music] AppleScript error \(code): \(err["NSAppleScriptErrorMessage"] ?? "")")
                }
            }
        }
    }

    // MARK: - Interpolation

    private func startInterpolation() {
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.hasMedia, self.info.isPlaying, self.info.duration > 0 else { return }
            let delta = Date().timeIntervalSince(self.lastUpdateTime)
            let interpolated = self.lastElapsed + delta
            guard interpolated <= self.info.duration else { return }
            self.info = MediaPlaybackInfo(
                title: self.info.title, artist: self.info.artist, album: self.info.album,
                isPlaying: self.info.isPlaying, duration: self.info.duration,
                elapsedTime: interpolated, artwork: self.info.artwork,
                volume: self.info.volume, isShuffle: self.info.isShuffle, repeatMode: self.info.repeatMode
            )
        }
    }

    // MARK: - Debug Simulation

    #if DEBUG
    private func startSimulation() {
        simulatedSongs = [
            NowPlayingResult(
                title: "夜曲", artist: "周杰伦", album: "十一月的萧邦",
                duration: 235, position: 0, isPlaying: true, artwork: nil
            ),
            NowPlayingResult(
                title: "晴天", artist: "周杰伦", album: "叶惠美",
                duration: 269, position: 0, isPlaying: true, artwork: nil
            ),
            NowPlayingResult(
                title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera",
                duration: 354, position: 0, isPlaying: true, artwork: nil
            ),
            NowPlayingResult(
                title: "Blinding Lights", artist: "The Weeknd", album: "After Hours",
                duration: 200, position: 0, isPlaying: true, artwork: nil
            ),
            NowPlayingResult(
                title: "起风了", artist: "买辣椒也用券", album: "起风了",
                duration: 325, position: 0, isPlaying: true, artwork: nil
            ),
        ]
        simulationIndex = 0
        applySimulatedSong()

        // Auto-advance every 15 seconds for testing
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSimulating else { return }
            self.simulationIndex = (self.simulationIndex + 1) % self.simulatedSongs.count
            self.applySimulatedSong()
        }
    }

    private func applySimulatedSong() {
        guard simulationIndex < simulatedSongs.count else { return }
        let song = simulatedSongs[simulationIndex]
        print("[Music] Simulated: \(song.title) — \(song.artist)")
        applyResult(song)
    }

    /// Manually advance to next simulated song
    func simulateNext() {
        guard isSimulating, !simulatedSongs.isEmpty else { return }
        simulationIndex = (simulationIndex + 1) % simulatedSongs.count
        applySimulatedSong()
    }

    /// Manually go to previous simulated song
    func simulatePrevious() {
        guard isSimulating, !simulatedSongs.isEmpty else { return }
        simulationIndex = (simulationIndex - 1 + simulatedSongs.count) % simulatedSongs.count
        applySimulatedSong()
    }

    /// Toggle simulated playback
    func simulateTogglePlay() {
        guard isSimulating else { return }
        let current = info
        let nowPlaying = !current.isPlaying
        // Update interpolation state so resume doesn't jump
        lastElapsed = current.elapsedTime
        lastUpdateTime = .now
        info = MediaPlaybackInfo(
            title: current.title, artist: current.artist, album: current.album,
            isPlaying: nowPlaying, duration: current.duration,
            elapsedTime: current.elapsedTime, artwork: current.artwork,
            volume: current.volume, isShuffle: current.isShuffle, repeatMode: current.repeatMode
        )
    }
    #endif
}

// MARK: - Media Key Sender

protocol MediaKeySenderProtocol {
    func sendPlayPause()
    func sendNextTrack()
    func sendPreviousTrack()
}

struct DefaultMediaKeySender: MediaKeySenderProtocol {
    func sendPlayPause()   { sendKey(0x10) }
    func sendNextTrack()    { sendKey(0x12) }
    func sendPreviousTrack() { sendKey(0x11) }
    private func sendKey(_ keyCode: CGKeyCode) {
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }
}
