//
//  LyricsServiceProtocol.swift
//  MacIsland
//
//  歌词服务协议 + 数据模型
//

import Foundation

// MARK: - LRC Line

/// 一行时间同步歌词
struct LrcLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String

    static func == (lhs: LrcLine, rhs: LrcLine) -> Bool {
        lhs.time == rhs.time && lhs.text == rhs.text
    }
}

// MARK: - Lyrics Document

/// 解析后的歌词文档
struct LyricsDocument: Equatable {
    let lines: [LrcLine]
    let source: String

    static let empty = LyricsDocument(lines: [], source: "")

    func activeLineIndex(at elapsed: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        var result: Int?
        for (i, line) in lines.enumerated() {
            if line.time <= elapsed { result = i } else { break }
        }
        return result
    }
}

// MARK: - Lyrics Service Protocol

/// 歌词服务协议
protocol LyricsServiceProtocol: AnyObject {
    var currentLyrics: LyricsDocument { get }
    var isLoading: Bool { get }
    func fetchLyrics(title: String, artist: String, duration: TimeInterval) async
    func clearLyrics()
}
