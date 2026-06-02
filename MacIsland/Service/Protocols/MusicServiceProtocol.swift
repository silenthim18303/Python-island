//
//  MusicServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import AppKit

// MARK: - Media Playback Info

/// 媒体播放信息
struct MediaPlaybackInfo {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let artwork: NSImage?
    let volume: Float
    let isShuffle: Bool
    let repeatMode: Int  // 0=off, 1=all, 2=one

    /// 空播放信息（无曲目时的占位）。volume 取 0.5 作为音量滑块的初始中位，非笔误。
    static let empty = MediaPlaybackInfo(
        title: "", artist: "", album: "",
        isPlaying: false, duration: 0, elapsedTime: 0, artwork: nil,
        volume: 0.5, isShuffle: false, repeatMode: 0
    )

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
    var info: MediaPlaybackInfo { get }
    var hasMedia: Bool { get }
    func startMonitoring()
    func stopMonitoring()
    func togglePlay()
    func nextTrack()
    func previousTrack()
    func setVolume(_ volume: Float)
    func seek(to time: TimeInterval)
    func toggleShuffle()
    func cycleRepeat()
}
