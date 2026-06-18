//
//  HoverView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

/// Hover state view — shows music controls when playing, weather when not
struct HoverView: View {
    @EnvironmentObject var weatherService: QWeatherService
    @EnvironmentObject var musicService: MusicService

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if musicService.hasMedia {
                musicSection
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            } else {
                weatherSection
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }

            controlButtons
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Music Section

    private var musicSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 封面
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.4))
                    )
            }

            // 歌曲信息
            VStack(alignment: .leading, spacing: 2) {
                Text(musicService.info.title)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !musicService.info.artist.isEmpty {
                    Text(musicService.info.artist)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Weather Section

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: weatherService.weather.iconSystemName)
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)

                Text("\(Int(weatherService.weather.temperature))°C")
                    .font(.system(size: Theme.FontSize.title, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }

            Text("\(weatherService.weather.description) · \(weatherService.weather.windDir)")
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)

            if !weatherService.weather.locationDisplay.isEmpty {
                Text(weatherService.weather.locationDisplay)
                    .font(.system(size: Theme.FontSize.caption2, weight: .regular))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            if musicService.hasMedia {
                controlButton(icon: "backward.fill", size: 13) {
                    musicService.previousTrack()
                }

                controlButton(icon: musicService.info.isPlaying ? "pause.fill" : "play.fill", size: 16, emphasized: true) {
                    musicService.togglePlay()
                }

                controlButton(icon: "forward.fill", size: 13) {
                    musicService.nextTrack()
                }
            }
        }
        .frame(minWidth: musicService.hasMedia ? 100 : 0, alignment: .trailing)
    }

    private func controlButton(
        icon: String,
        size: CGFloat,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(emphasized ? .black.opacity(0.88) : .textPrimary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(emphasized ? Color.white.opacity(0.92) : Color.white.opacity(0.10))
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(emphasized ? 0.24 : 0.12), lineWidth: 0.5)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
