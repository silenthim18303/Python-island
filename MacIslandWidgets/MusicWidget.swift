//
//  MusicWidget.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import WidgetKit
import SwiftUI
import AppIntents

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
    let updatedAt: Date?

    static var placeholder: MusicEntry {
        MusicEntry(date: Date(), title: "Midnight Drive", artist: "MacIsland",
                   isPlaying: true, progress: 0.45, updatedAt: Date())
    }

    static func fromUserDefaults() -> MusicEntry {
        let hasMedia = WidgetConstants.bool("widget_music_hasMedia")
        let ts = WidgetConstants.double("widget_music_updated_at")
        let updatedAt = ts > 0 ? Date(timeIntervalSince1970: ts) : nil

        guard hasMedia else {
            return MusicEntry(date: Date(), title: "", artist: "", isPlaying: false, progress: 0, updatedAt: updatedAt)
        }

        return MusicEntry(
            date: Date(),
            title: WidgetConstants.string("widget_music_title") ?? "",
            artist: WidgetConstants.string("widget_music_artist") ?? "",
            isPlaying: WidgetConstants.bool("widget_music_isPlaying"),
            progress: WidgetConstants.double("widget_music_progress"),
            updatedAt: updatedAt
        )
    }

    var hasMedia: Bool { !title.isEmpty }
    var clampedProgress: Double { min(max(progress, 0), 1) }
    var statusText: String { isPlaying ? "播放中" : "已暂停" }
    var updateString: String { WidgetFormat.relativeTime(updatedAt) }
}

// MARK: - Music Widget

struct MusicWidget: Widget {
    let kind = "MusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicTimelineProvider()) { entry in
            MusicWidgetView(entry: entry)
                .macIslandWidgetBackground()
        }
        .configurationDisplayName(WidgetL10n.musicDisplayName)
        .description(WidgetL10n.musicDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
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
        VStack(alignment: .leading, spacing: 8) {
            if entry.hasMedia {
                WidgetHeader(
                    icon: entry.isPlaying ? "play.fill" : "pause.fill",
                    title: WidgetL10n.musicTitle,
                    trailing: entry.statusText,
                    color: .purple
                )

                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(entry.artist.isEmpty ? WidgetL10n.musicUnknownArtist : entry.artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                WidgetProgressBar(value: entry.clampedProgress, color: .purple, height: 3)

                HStack {
                    Text("\(Int(entry.clampedProgress * 100))%")
                    Spacer()
                    Text(entry.updateString)
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            } else {
                Spacer()
                WidgetEmptyState(icon: "music.note", message: WidgetL10n.musicNoPlayback)
                Spacer()
            }
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.hasMedia {
                WidgetHeader(icon: "music.note", title: WidgetL10n.musicNowPlaying, trailing: entry.updateString, color: .purple)

                HStack(spacing: 12) {
                    albumArt(size: 50)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(entry.artist.isEmpty ? WidgetL10n.musicUnknownArtist : entry.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        WidgetProgressBar(value: entry.clampedProgress, color: .purple, height: 3)

                        HStack(spacing: 10) {
                            Label(entry.statusText, systemImage: entry.isPlaying ? "waveform" : "pause.circle")
                            Text("\(Int(entry.clampedProgress * 100))%")

                            Spacer()

                            // 播放/暂停按钮
                            Button(intent: MusicPlayPauseIntent()) {
                                Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.purple))
                            }
                            .buttonStyle(.plain)

                            // 下一首按钮
                            Button(intent: MusicNextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Color.purple.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                Spacer()
                WidgetEmptyState(icon: "music.note", message: WidgetL10n.musicNoContent)
                Spacer()
            }
        }
        .padding()
    }

    private func albumArt(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.purple.opacity(0.16))
            .overlay(
                Image(systemName: entry.isPlaying ? "waveform" : "music.note")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.purple)
            )
            .frame(width: size, height: size)
    }
}
