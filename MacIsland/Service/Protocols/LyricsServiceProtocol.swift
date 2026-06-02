
//
//  LyricsServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - LRC Line

/// A single line of time-synced lyrics
struct LrcLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval  // seconds from start
    let text: String

    static func == (lhs: LrcLine, rhs: LrcLine) -> Bool {
        lhs.time == rhs.time && lhs.text == rhs.text
    }
}

// MARK: - Lyrics Document

/// Parsed lyrics for a song
struct LyricsDocument: Equatable {
    let lines: [LrcLine]
    let source: String  // e.g. "LRCLIB"

    static let empty = LyricsDocument(lines: [], source: "")

    /// Find the index of the lyric line active at a given elapsed time
    func activeLineIndex(at elapsed: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        // Find the last line whose time <= elapsed
        var result: Int?
        for (i, line) in lines.enumerated() {
            if line.time <= elapsed {
                result = i
            } else {
                break
            }
        }
        return result
    }
}

// MARK: - Lyrics Service Protocol

/// 歌词服务 — 多源获取并暴露当前曲目的同步歌词
protocol LyricsServiceProtocol: AnyObject {
    var currentLyrics: LyricsDocument { get }
    var isLoading: Bool { get }
    var lastError: String? { get }
    func fetchLyrics(title: String, artist: String, duration: TimeInterval) async
    func clearLyrics()
}
