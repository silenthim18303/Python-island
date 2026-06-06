//
//  MusicWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI

// MARK: - Music Timeline Provider

struct MusicTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        let entry = MusicEntry.fromUserDefaults()
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 10, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Music Entry

struct MusicEntry: TimelineEntry {
    let date: Date
    let title: String
    let artist: String
    let isPlaying: Bool
    let progress: Double

    static var placeholder: MusicEntry {
        MusicEntry(date: Date(), title: "Song Title", artist: "Artist",
                   isPlaying: true, progress: 0.45)
    }

    static func fromUserDefaults() -> MusicEntry {
        let d = WidgetConstants.sharedDefaults
        let hasMedia = d.bool(forKey: "widget_music_hasMedia")

        guard hasMedia else {
            return MusicEntry(date: Date(), title: "No Playback", artist: "",
                              isPlaying: false, progress: 0)
        }

        return MusicEntry(
            date: Date(),
            title: d.string(forKey: "widget_music_title") ?? "No Playback",
            artist: d.string(forKey: "widget_music_artist") ?? "",
            isPlaying: d.bool(forKey: "widget_music_isPlaying"),
            progress: d.double(forKey: "widget_music_progress")
        )
    }

    var hasMedia: Bool { !title.isEmpty && title != "No Playback" }
}

// MARK: - Music Widget

struct MusicWidget: Widget {
    let kind = "MusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicTimelineProvider()) { entry in
            MusicWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("音乐")
        .description("显示当前播放的音乐")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Music Widget View

struct MusicWidgetView: View {
    let entry: MusicEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 6) {
            if entry.hasMedia {
                albumArt(size: 32)

                Text(entry.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(entry.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                progressBar(height: 2)
            } else {
                WidgetEmptyState(icon: "music.note", message: "No Playback")
            }
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
            if entry.hasMedia {
                albumArt(size: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(entry.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    progressBar(height: 3)

                    HStack(spacing: 4) {
                        Image(systemName: entry.isPlaying ? "play.fill" : "pause.fill")
                            .font(.system(size: 8))
                        Text(entry.isPlaying ? "Playing" : "Paused")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
            } else {
                WidgetEmptyState(icon: "music.note", message: "No music playing")
            }

            Spacer()
        }
        .padding()
    }

    private func albumArt(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.15)
            .fill(LinearGradient(
                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.accentColor)
            )
    }

    private func progressBar(height: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * entry.progress, height: height)
            }
        }
        .frame(height: height)
    }
}
