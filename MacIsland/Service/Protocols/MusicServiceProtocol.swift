//
//  MusicServiceProtocol.swift
//  MacIsland
//
//  音乐服务协议 + 数据模型
//

import Foundation
import AppKit

// MARK: - Music Info

/// 当前播放信息
struct MusicInfo {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let isPlaying: Bool
    let artwork: NSImage?

    static let empty = MusicInfo(
        title: "", artist: "", album: "",
        duration: 0, elapsedTime: 0, isPlaying: false, artwork: nil
    )

    static func == (lhs: MusicInfo, rhs: MusicInfo) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
            && lhs.duration == rhs.duration && lhs.elapsedTime == rhs.elapsedTime
            && lhs.isPlaying == rhs.isPlaying
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return elapsedTime / duration
    }

    var formattedElapsed: String { formatTime(elapsedTime) }
    var formattedDuration: String { formatTime(duration) }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Music Service Protocol

/// 音乐服务协议
protocol MusicServiceProtocol: AnyObject {
    var info: MusicInfo { get }
    var hasMedia: Bool { get }
    var canSeek: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func togglePlay()
    func nextTrack()
    func previousTrack()
    func setVolume(_ volume: Float)
    func seek(to time: TimeInterval)
}
