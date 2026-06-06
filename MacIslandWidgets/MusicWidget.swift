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
        MusicEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        completion(MusicEntry.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        // 从 UserDefaults 读取音乐数据
        let entry = MusicEntry.fromUserDefaults()

        // 每 5 秒刷新一次（音乐状态变化快）
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
        MusicEntry(
            date: Date(),
            title: "歌曲名称",
            artist: "艺术家",
            isPlaying: true,
            progress: 0.45
        )
    }

    static func fromUserDefaults() -> MusicEntry {
        let defaults = UserDefaults.standard
        let hasMedia = defaults.bool(forKey: "widget_music_hasMedia")

        guard hasMedia else {
            return MusicEntry(
                date: Date(),
                title: "暂无播放",
                artist: "",
                isPlaying: false,
                progress: 0
            )
        }

        return MusicEntry(
            date: Date(),
            title: defaults.string(forKey: "widget_music_title") ?? "暂无播放",
            artist: defaults.string(forKey: "widget_music_artist") ?? "",
            isPlaying: defaults.bool(forKey: "widget_music_isPlaying"),
            progress: defaults.double(forKey: "widget_music_progress")
        )
    }
}

// MARK: - Music Widget

struct MusicWidget: Widget {
    let kind: String = "MusicWidget"

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
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: - Small View

    private var smallView: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.isPlaying ? "music.note" : "music.note")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)

            Text(entry.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(entry.artist)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // 进度条
            ProgressView(value: entry.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .frame(height: 2)
        }
        .padding()
    }

    // MARK: - Medium View

    private var mediumView: some View {
        HStack(spacing: 12) {
            // 左侧：封面占位
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                )

            // 右侧：歌曲信息
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(entry.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 进度条
                ProgressView(value: entry.progress)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 3)

                // 播放状态
                HStack(spacing: 4) {
                    Image(systemName: entry.isPlaying ? "play.fill" : "pause.fill")
                        .font(.system(size: 8))
                    Text(entry.isPlaying ? "播放中" : "已暂停")
                        .font(.system(size: 9))
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MusicWidget()
} timeline: {
    MusicEntry.placeholder
}
