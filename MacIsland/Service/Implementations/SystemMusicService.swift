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
import CoreAudio
import AudioToolbox

// MARK: - Now Playing Result (shared across adapters)

struct NowPlayingResult {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
    let artwork: NSImage?
}

// MARK: - Player Adapter Protocol

protocol PlayerAdapter {
    var bundleID: String { get }
    var displayName: String { get }
    var supportsAppleScript: Bool { get }
    var supportsURLScheme: Bool { get }

    /// 通过 AppleScript 查询当前播放状态（仅支持 AppleScript 的播放器实现）
    func fetchPlaybackInfo() async -> NowPlayingResult?

    /// 发送播放控制命令（play/pause/next/prev），通过 URL Scheme
    func sendCommand(_ command: String)
}

extension PlayerAdapter {
    var supportsURLScheme: Bool { false }
    func sendCommand(_ command: String) {}
}

// MARK: - Apple Music Adapter

struct AppleMusicAdapter: PlayerAdapter {
    let bundleID = "com.apple.Music"
    let displayName = "Music"
    let supportsAppleScript = true

    func fetchPlaybackInfo() async -> NowPlayingResult? {
        let script = """
        tell application "Music"
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
        let result = await runAppleScriptForResult(script)
        switch result {
        case .success(let output): return parseAppleScriptResult(output)
        case .notAuthorized: return nil
        case .failed: return nil
        }
    }
}

// MARK: - Spotify Adapter

struct SpotifyAdapter: PlayerAdapter {
    let bundleID = "com.spotify.client"
    let displayName = "Spotify"
    let supportsAppleScript = true

    func fetchPlaybackInfo() async -> NowPlayingResult? {
        let script = """
        tell application "Spotify"
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
        let result = await runAppleScriptForResult(script)
        switch result {
        case .success(let output): return parseAppleScriptResult(output, durationInMs: true)
        case .notAuthorized: return nil
        case .failed: return nil
        }
    }
}

// MARK: - Generic Adapter (Chinese players without AppleScript)

struct GenericAdapter: PlayerAdapter {
    let bundleID: String
    let displayName: String
    let supportsAppleScript = false

    func fetchPlaybackInfo() async -> NowPlayingResult? {
        return nil // No AppleScript support; relies on notifications + CGWindowList
    }
}

// MARK: - NetEase Cloud Music Adapter (orpheus:// URL Scheme)

struct NetEaseAdapter: PlayerAdapter {
    let bundleID = "com.netease.163music"
    let displayName = "网易云音乐"
    let supportsAppleScript = false
    let supportsURLScheme = true

    func fetchPlaybackInfo() async -> NowPlayingResult? {
        return nil // Relies on notifications + CGWindowList
    }

    func sendCommand(_ command: String) {
        if let url = URL(string: "orpheus://\(command)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - AppleScript Helpers (shared by adapters)

enum AppleScriptResult {
    case success(String)
    case notAuthorized
    case failed
}

private func runAppleScriptForResult(_ source: String) async -> AppleScriptResult {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else {
                continuation.resume(returning: .failed)
                return
            }
            let output = script.executeAndReturnError(&error)
            if let err = error {
                let code = err["NSAppleScriptErrorNumber"] as? Int ?? 0
                // -1743: Not authorized to send Apple events
                if code == -1743 {
                    continuation.resume(returning: .notAuthorized)
                    return
                }
                // -1700: can't get object (player stopped), -600: app not running
                if code != -1700 && code != -600 {
                    print("[Music] AppleScript error \(code): \(err["NSAppleScriptErrorMessage"] ?? "")")
                }
                continuation.resume(returning: .failed)
                return
            }
            continuation.resume(returning: .success(output.stringValue ?? ""))
        }
    }
}

private func parseAppleScriptResult(_ result: String, durationInMs: Bool = false) -> NowPlayingResult? {
    let parts = result.components(separatedBy: "|||")
    guard parts.count >= 6 else { return nil }
    let title = parts[0].trimmingCharacters(in: .whitespaces)
    guard !title.isEmpty else { return nil }
    let artist = parts[1].trimmingCharacters(in: .whitespaces)
    let album = parts[2].trimmingCharacters(in: .whitespaces)
    let duration = (Double(parts[3]) ?? 0) / (durationInMs ? 1000.0 : 1.0)
    let position = Double(parts[4]) ?? 0
    let isPlaying = parts[5].trimmingCharacters(in: .whitespaces).lowercased() == "true"
    return NowPlayingResult(
        title: title, artist: artist, album: album,
        duration: duration, position: position,
        isPlaying: isPlaying, artwork: nil
    )
}

// MARK: - System music service — event-driven via distributed notifications + CGWindowList fallback

final class SystemMusicService: MusicServiceProtocol, ObservableObject {
    @Published private(set) var info: MediaPlaybackInfo = .empty
    @Published private(set) var hasMedia = false

    private var interpolationTimer: Timer?
    private var windowPollTimer: Timer?
    private var appleScriptPollTimer: Timer?
    private var simulationTimer: Timer?
    private var lastElapsed: TimeInterval = 0
    private var lastUpdateTime: Date = .now
    private var lastTitle: String = ""
    private let mediaKeySender: MediaKeySenderProtocol
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?

    // Player adapters — NetEase uses URL Scheme, others use media keys
    private let adapters: [PlayerAdapter] = [
        AppleMusicAdapter(),
        SpotifyAdapter(),
        NetEaseAdapter(),
    ]
    private var activeAdapter: PlayerAdapter?
    private var appleScriptAuthorized = false // 默认关闭，仅在确认有权限时启用

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
        PlayerDef(bundleID: "com.luna.music",              displayName: "汽水音乐"),
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
        // Candidate names — may not fire on all versions
        Notification.Name("com.kuwo.mac.playerInfo"),
        Notification.Name("com.kuwo.mac.playerStateChanged"),
        Notification.Name("com.luna.music.playerInfo"),
        Notification.Name("com.luna.music.playerStateChanged"),
    ]

    // MediaRemote disabled on macOS 26+ — private API calls are blocked
    // Keeping notification name listeners for DistributedNotification-based detection

    // MARK: - System Volume (CoreAudio)

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
            let newVolume = self.getSystemVolume()
            DispatchQueue.main.async {
                self.updateVolume(newVolume)
            }
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

    private func updateVolume(_ volume: Float) {
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: info.isPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: volume, isShuffle: info.isShuffle, repeatMode: info.repeatMode
        )
    }

    // MARK: - Player Detection & AppleScript Polling

    /// 检测当前活跃播放器
    private func detectActivePlayer() {
        // 查找正在运行的已知播放器，设置适配器（用于 URL Scheme 控制等）
        for adapter in adapters {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: adapter.bundleID)
            if running.first != nil {
                activeAdapter = adapter
                // 如果有 AppleScript 权限，启动轮询获取精确进度
                if appleScriptAuthorized, adapter.supportsAppleScript {
                    startAppleScriptPolling()
                }
                return
            }
        }
        activeAdapter = nil
        stopAppleScriptPolling()
        // 使用 CGWindowList 兜底检测
        pollWindowTitles()
    }

    /// 根据 bundleID 查找适配器
    private func adapterForBundleID(_ bundleID: String) -> PlayerAdapter? {
        adapters.first { $0.bundleID == bundleID }
    }

    /// 检测 AppleScript 权限是否可用 — 尝试一次简单调用
    private func checkAppleScriptPermission() {
        guard !appleScriptAuthorized else { return }
        let script = """
        tell application "System Events"
            name of first process
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    DispatchQueue.main.async {
                        self?.appleScriptAuthorized = true
                        print("[Music] AppleScript 权限可用，启用实时轮询")
                        self?.detectActivePlayer()
                    }
                }
            }
        }
    }

    /// 启动 AppleScript 轮询（1 秒间隔，仅在支持的播放器活跃时）
    private func startAppleScriptPolling() {
        appleScriptPollTimer?.invalidate()
        appleScriptPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let adapter = self.activeAdapter else { return }
            Task { @MainActor in
                let script = """
                tell application "\(adapter.displayName)"
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
                let result = await runAppleScriptForResult(script)
                switch result {
                case .success(let output):
                    if let parsed = parseAppleScriptResult(output, durationInMs: adapter.bundleID == "com.spotify.client") {
                        self.applyAppleScriptResult(parsed)
                    }
                case .notAuthorized:
                    self.handleAppleScriptNotAuthorized()
                case .failed:
                    // Player may have closed
                    self.activeAdapter = nil
                    self.stopAppleScriptPolling()
                    self.detectActivePlayer()
                }
            }
        }
        // Immediate first poll
        Task { @MainActor [weak self] in
            guard let self = self, let adapter = self.activeAdapter else { return }
            let script = """
            tell application "\(adapter.displayName)"
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
            let result = await runAppleScriptForResult(script)
            switch result {
            case .success(let output):
                if let parsed = parseAppleScriptResult(output, durationInMs: adapter.bundleID == "com.spotify.client") {
                    self.applyAppleScriptResult(parsed)
                }
            case .notAuthorized:
                self.handleAppleScriptNotAuthorized()
            case .failed:
                break
            }
        }
    }

    /// 停止 AppleScript 轮询
    private func stopAppleScriptPolling() {
        appleScriptPollTimer?.invalidate()
        appleScriptPollTimer = nil
    }

    /// 处理 AppleScript 权限被拒绝的情况
    private func handleAppleScriptNotAuthorized() {
        guard appleScriptAuthorized else { return }
        appleScriptAuthorized = false
        stopAppleScriptPolling()
        print("[Music] AppleScript 未授权，使用媒体键控制。")
    }

    /// 应用 AppleScript 查询结果（精确进度更新，不触发完整状态切换）
    private func applyAppleScriptResult(_ result: NowPlayingResult) {
        lastElapsed = result.position
        lastUpdateTime = .now
        lastTitle = result.title
        info = MediaPlaybackInfo(
            title: result.title, artist: result.artist, album: result.album,
            isPlaying: result.isPlaying, duration: result.duration,
            elapsedTime: result.position, artwork: result.artwork ?? info.artwork,
            volume: info.volume, isShuffle: info.isShuffle, repeatMode: info.repeatMode
        )
        hasMedia = true
    }

    // MARK: - Init

    init(mediaKeySender: MediaKeySenderProtocol = DefaultMediaKeySender()) {
        self.mediaKeySender = mediaKeySender
        // MediaRemote private API is blocked on macOS 26+ — no initialization needed

        // 订阅音乐状态变化，更新小组件数据
        $info.combineLatest($hasMedia)
            .receive(on: RunLoop.main)
            .sink { [weak self] info, hasMedia in
                WidgetDataManager.shared.updateMusic(
                    hasMedia: hasMedia,
                    title: info.title,
                    artist: info.artist,
                    isPlaying: info.isPlaying,
                    progress: info.progress
                )
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

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

        // 3a. 监听所有分布式通知（用于发现未知的播放器通知名称）
        // 注意：name: nil 可能无法接收所有通知，仅作为兜底
        for name in notificationNames {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(handleAnyNotification(_:)),
                name: name, object: nil
            )
        }

        // 3b. 当音乐播放器变为前台应用时，立即检测窗口标题
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )

        // 4. CGWindowList fallback polling (every 2s, for players without AppleScript/notifications)
        windowPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 对于不支持 AppleScript 的播放器（如网易云），持续轮询
            if !self.appleScriptAuthorized || self.activeAdapter?.supportsAppleScript == false {
                // 优先尝试 Accessibility API（网易云等 Electron 播放器）
                if let result = self.readNetEaseViaAccessibility() {
                    DispatchQueue.main.async { self.applyResult(result) }
                } else {
                    self.pollWindowTitles()
                }
            }
        }

        startInterpolation()

        // 检测 AppleScript 权限（如果可用则启用实时轮询）
        checkAppleScriptPermission()

        // 检测活跃播放器
        detectActivePlayer()

        // Initialize system volume and start listening for changes
        let currentVolume = getSystemVolume()
        updateVolume(currentVolume)
        startVolumeListener()
    }

    func stopMonitoring() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        windowPollTimer?.invalidate()
        windowPollTimer = nil
        appleScriptPollTimer?.invalidate()
        appleScriptPollTimer = nil
        activeAdapter = nil
        stopVolumeListener()
        #if DEBUG
        simulationTimer?.invalidate()
        simulationTimer = nil
        isSimulating = false
        #endif
    }

    // MARK: - Accessibility API (读取网易云等播放器的 UI 元素)

    /// 使用 Accessibility API 读取网易云播放器的歌曲信息
    private func readNetEaseViaAccessibility() -> NowPlayingResult? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.netease.163music").first else {
            return nil
        }
        let pid = app.processIdentifier
        let element = AXUIElementCreateApplication(pid)

        // 获取主窗口
        var windowValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windowValue)
        guard result == .success, let windows = windowValue as? [AXUIElement], !windows.isEmpty else {
            return nil
        }

        // 遍历所有窗口，查找包含歌曲信息的 UI 元素
        for window in windows {
            if let songInfo = extractSongInfo(from: window) {
                return songInfo
            }
        }
        return nil
    }

    /// 递归遍历 AX 元素树，查找歌曲标题和艺术家
    private func extractSongInfo(from element: AXUIElement) -> NowPlayingResult? {
        var childrenValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        guard let children = childrenValue as? [AXUIElement] else { return nil }

        var titles: [String] = []
        var roleDescription: String = ""

        for child in children {
            // 检查是否是文本元素
            var roleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
            let role = roleValue as? String ?? ""

            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""

            var descValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descValue)
            let desc = descValue as? String ?? ""

            var valueValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueValue)
            let value = valueValue as? String ?? ""

            // 收集有意义的文本
            let text = [title, desc, value].first { !$0.isEmpty } ?? ""
            if !text.isEmpty && !text.contains("MiniPlayer") && !text.contains("音乐") {
                titles.append(text)
            }

            // 递归查找子元素
            if titles.isEmpty {
                if let nested = extractSongInfo(from: child) {
                    return nested
                }
            }
        }

        // 尝试从收集的文本中解析歌曲信息
        if titles.count >= 2 {
            // 通常第一个是歌曲名，第二个是艺术家
            return NowPlayingResult(
                title: titles[0], artist: titles[1], album: "",
                duration: 0, position: 0, isPlaying: true, artwork: nil
            )
        } else if titles.count == 1 {
            // 尝试解析 "歌曲名 - 艺术家" 格式
            let parts = titles[0].components(separatedBy: " - ")
            if parts.count >= 2 {
                return NowPlayingResult(
                    title: parts[0].trimmingCharacters(in: .whitespaces),
                    artist: parts[1].trimmingCharacters(in: .whitespaces),
                    album: "", duration: 0, position: 0, isPlaying: true, artwork: nil
                )
            }
        }

        return nil
    }

    // MARK: - Metadata Enrichment (online API for Chinese players)

    private var metadataFetchTask: Task<Void, Never>?

    /// 当检测到新歌曲但缺少元数据时，在线获取封面和时长
    private func enrichMetadata(title: String, artist: String) {
        metadataFetchTask?.cancel()
        metadataFetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            // 等待 300ms 防止频繁请求
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            // 使用网易云搜索 API 获取歌曲元数据
            if let metadata = await self.searchSongMetadata(title: title, artist: artist) {
                guard !Task.isCancelled else { return }
                self.info = MediaPlaybackInfo(
                    title: self.info.title.isEmpty ? metadata.title : self.info.title,
                    artist: self.info.artist.isEmpty ? metadata.artist : self.info.artist,
                    album: metadata.album,
                    isPlaying: self.info.isPlaying,
                    duration: metadata.duration > 0 ? metadata.duration : self.info.duration,
                    elapsedTime: self.info.elapsedTime,
                    artwork: metadata.artwork ?? self.info.artwork,
                    volume: self.info.volume,
                    isShuffle: self.info.isShuffle,
                    repeatMode: self.info.repeatMode
                )
            }
        }
    }

    private struct SongMetadata {
        let title: String
        let artist: String
        let album: String
        let duration: TimeInterval
        let artwork: NSImage?
    }

    /// 通过网易云搜索 API 获取歌曲元数据
    private func searchSongMetadata(title: String, artist: String) async -> SongMetadata? {
        let query = "\(title) \(artist)"
        guard let searchURL = URL(string: "https://music.163.com/api/search/get/web") else { return nil }

        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&limit=1&offset=0".data(using: .utf8)
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  let firstSong = songs.first else {
                return nil
            }

            let songTitle = firstSong["name"] as? String ?? title
            let durationMs = firstSong["duration"] as? TimeInterval ?? 0
            let duration = durationMs / 1000.0

            // 提取艺术家名
            var artistName = artist
            if let artists = firstSong["artists"] as? [[String: Any]],
               let firstArtist = artists.first,
               let name = firstArtist["name"] as? String {
                artistName = name
            }

            // 提取专辑名和封面 URL
            var albumName = ""
            var artworkURL: String?
            if let album = firstSong["album"] as? [String: Any] {
                albumName = album["name"] as? String ?? ""
                artworkURL = album["picUrl"] as? String
            }

            // 下载封面图片
            var artwork: NSImage?
            if let urlString = artworkURL, let url = URL(string: urlString) {
                artwork = await downloadImage(from: url)
            }

            return SongMetadata(
                title: songTitle, artist: artistName, album: albumName,
                duration: duration, artwork: artwork
            )
        } catch {
            print("[Music] Metadata fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    private func downloadImage(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    // MARK: - Notification Handlers

    /// 监听所有分布式通知，识别来自音乐播放器的通知
    @objc private func handleAnyNotification(_ notification: Notification) {
        let name = notification.name.rawValue
        // 跳过系统和 MacIsland 自己的通知
        guard !name.hasPrefix("com.apple.") && !name.contains("MacIsland") else { return }

        // 检查是否来自已知播放器
        let bundleID = notification.object as? String ?? ""
        let isKnownPlayer = players.contains { $0.bundleID == bundleID }

        if isKnownPlayer || name.contains("netease") || name.contains("qqmusic") || name.contains("kugou") || name.contains("kuwo") || name.contains("luna") {
            print("[Music] Relevant notification: \(name) from: \(bundleID)")
            if let userInfo = notification.userInfo {
                print("[Music]   keys: \(Array(userInfo.keys))")
                for (key, value) in userInfo {
                    print("[Music]   \(key) = \(String(describing: value).prefix(100))")
                }
            } else {
                print("[Music]   no userInfo")
            }
        }
    }

    /// MediaRemote 通知占位处理 —— macOS 26+ 私有 API 已被禁用，无法取详细 NowPlaying 信息，
    /// 仅记录日志；实际曲目数据依赖播放器自身的分布式通知与 CGWindowList 兜底检测。
    /// 当收到 MediaRemote 通知时，尝试检测活跃播放器（可能是 Apple Music）。
    @objc private func handleMediaNotification(_ notification: Notification) {
        print("[Music] MediaRemote notification: \(notification.name)")
        // MediaRemote notifications may indicate Apple Music is active
        if activeAdapter == nil {
            detectActivePlayer()
        }
    }

    @objc private func handleAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let bundleID = app.bundleIdentifier ?? ""
        // 如果激活的是已知播放器，设置活跃适配器并立即检测
        if players.contains(where: { $0.bundleID == bundleID }) && !bundleID.contains("MobileSMS") {
            activeAdapter = adapterForBundleID(bundleID)
            print("[Music] Player activated: \(app.localizedName ?? bundleID)")
            pollWindowTitles()
        }
    }

    @objc private func handlePlayerNotification(_ notification: Notification) {
        print("[Music] Player notification: \(notification.name)")

        let notificationName = notification.name.rawValue

        // 设置活跃适配器（用于 URL Scheme 控制等）
        if notificationName.contains("apple.Music") {
            if activeAdapter?.bundleID != "com.apple.Music" {
                activeAdapter = adapterForBundleID("com.apple.Music")
                if appleScriptAuthorized { startAppleScriptPolling() }
            }
        } else if notificationName.contains("spotify") {
            if activeAdapter?.bundleID != "com.spotify.client" {
                activeAdapter = adapterForBundleID("com.spotify.client")
                if appleScriptAuthorized { startAppleScriptPolling() }
            }
        } else if notificationName.contains("netease") {
            if activeAdapter?.bundleID != "com.netease.163music" {
                activeAdapter = adapterForBundleID("com.netease.163music")
            }
        }

        guard let userInfo = notification.userInfo else {
            print("[Music] Notification has no userInfo, falling back to CGWindowList")
            // 通知无 userInfo 但播放器已活跃，立即通过 CGWindowList 获取曲目信息
            pollWindowTitles()
            return
        }

        // 打印完整 userInfo 用于调试（仅首次）
        if notificationName.contains("netease") {
            print("[Music] NetEase notification userInfo keys: \(Array(userInfo.keys))")
            for (key, value) in userInfo {
                print("[Music]   \(key) = \(value)")
            }
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

            // 优先检测已确认活跃的播放器（来自通知或 adapter 检测）
            if let activeBundleID = self.activeAdapter?.bundleID {
                if let app = NSRunningApplication.runningApplications(withBundleIdentifier: activeBundleID).first {
                    let pid = app.processIdentifier
                    if let result = self.readWindowTitle(pid: pid, appName: app.localizedName ?? activeBundleID) {
                        print("[Music] CGWindowList detected: \(result.title) — \(result.artist)")
                        DispatchQueue.main.async { self.applyResult(result) }
                        return
                    }
                }
            }

            // 兜底：遍历所有播放器
            for player in self.players {
                guard !player.displayName.isEmpty else { continue }
                let running = NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleID)
                guard let app = running.first else { continue }
                let pid = app.processIdentifier

                if let result = self.readWindowTitle(pid: pid, appName: player.displayName) {
                    print("[Music] CGWindowList detected: \(result.title) — \(result.artist)")
                    DispatchQueue.main.async { self.applyResult(result) }
                    return
                }
            }
        }
    }

    private func readWindowTitle(pid: pid_t, appName: String) -> NowPlayingResult? {
        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid else { continue }

            let title = window[kCGWindowName as String] as? String ?? ""
            guard !title.isEmpty else { continue }

            print("[Music] [\(appName)] window: \"\(title)\"")

            let blacklist = [
                // UI 功能标签
                "登录", "设置", "偏好", "发现", "我的", "歌单", "排行榜",
                "Settings", "Login", "Sign", "Browse", "Search", "Library",
                "下载", "关注", "消息", "动态", "会员", "商城",
                "迷你", "Mini", "歌词", "Lyrics", "均衡器", "Equalizer",
                "正在播放", "Now Playing", "播放列表", "Playlist",
                // 播放器应用名（不是歌曲名）
                "音乐", "Music", "Spotify", "网易云音乐", "QQ音乐", "酷狗音乐",
                "酷我音乐", "汽水音乐", "全民K歌", "kugou", "kuwo",
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

        // 当缺少封面或时长时，通过在线 API 补充元数据
        if result.artwork == nil || result.duration == 0 {
            enrichMetadata(title: result.title, artist: result.artist)
        }
    }

    // MARK: - Playback Controls

    func togglePlay() {
        #if DEBUG
        if isSimulating { simulateTogglePlay(); return }
        #endif

        // 乐观更新 UI（立即翻转，按钮图标即时响应）
        let newPlaying = !info.isPlaying
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: newPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: info.volume, isShuffle: info.isShuffle, repeatMode: info.repeatMode
        )

        if let adapter = activeAdapter {
            if appleScriptAuthorized, adapter.supportsAppleScript {
                let appName = adapter.displayName
                let command = newPlaying ? "play" : "pause"
                let script = """
                tell application "\(appName)"
                    \(command)
                end tell
                """
                runAppleScript(script)
            } else if adapter.supportsURLScheme {
                adapter.sendCommand(newPlaying ? "play" : "pause")
            } else {
                mediaKeySender.sendPlayPause()
            }
        } else {
            mediaKeySender.sendPlayPause()
        }
    }

    func nextTrack() {
        #if DEBUG
        if isSimulating { simulateNext(); return }
        #endif

        if let adapter = activeAdapter {
            if appleScriptAuthorized, adapter.supportsAppleScript {
                let appName = adapter.displayName
                let script = """
                tell application "\(appName)"
                    next track
                end tell
                """
                runAppleScript(script)
            } else if adapter.supportsURLScheme {
                adapter.sendCommand("next")
            } else {
                mediaKeySender.sendNextTrack()
            }
        } else {
            mediaKeySender.sendNextTrack()
        }
    }

    func previousTrack() {
        #if DEBUG
        if isSimulating { simulatePrevious(); return }
        #endif

        if let adapter = activeAdapter {
            if appleScriptAuthorized, adapter.supportsAppleScript {
                let appName = adapter.displayName
                let script = """
                tell application "\(appName)"
                    previous track
                end tell
                """
                runAppleScript(script)
            } else if adapter.supportsURLScheme {
                adapter.sendCommand("prev")
            } else {
                mediaKeySender.sendPreviousTrack()
            }
        } else {
            mediaKeySender.sendPreviousTrack()
        }
    }

    func setVolume(_ volume: Float) {
        setSystemVolume(volume)
        // Volume listener will auto-update info.volume, but update immediately for responsiveness
        updateVolume(max(0, min(1, volume)))
    }

    func seek(to time: TimeInterval) {
        guard appleScriptAuthorized else { return }
        let appName = activeAdapter?.displayName ?? "Music"
        let script = """
        tell application "\(appName)"
            if player state is playing then
                set player position to \(time)
            end if
        end tell
        """
        runAppleScript(script)
    }

    func toggleShuffle() {
        let newShuffle = !info.isShuffle
        if appleScriptAuthorized {
            if activeAdapter?.bundleID == "com.spotify.client" {
                let script = """
                tell application "Spotify"
                    set shuffling enabled to \(newShuffle)
                end tell
                """
                runAppleScript(script)
            } else {
                let script = """
                tell application "Music"
                    set shuffle enabled to \(newShuffle)
                end tell
                """
                runAppleScript(script)
            }
        }
        info = MediaPlaybackInfo(
            title: info.title, artist: info.artist, album: info.album,
            isPlaying: info.isPlaying, duration: info.duration,
            elapsedTime: info.elapsedTime, artwork: info.artwork,
            volume: info.volume, isShuffle: newShuffle, repeatMode: info.repeatMode
        )
    }

    func cycleRepeat() {
        let newMode = (info.repeatMode + 1) % 3
        if appleScriptAuthorized {
            if activeAdapter?.bundleID == "com.spotify.client" {
                let repeating = newMode != 0
                let script = """
                tell application "Spotify"
                    set repeating enabled to \(repeating)
                end tell
                """
                runAppleScript(script)
            } else {
                let modeString: String
                switch newMode {
                case 0: modeString = "off"
                case 1: modeString = "all"
                case 2: modeString = "one"
                default: modeString = "off"
                }
                let script = """
                tell application "Music"
                    set song repeat to \(modeString)
                end tell
                """
                runAppleScript(script)
            }
        }
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
