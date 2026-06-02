//
//  HoverView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

/// Hover state view — shows music controls when playing, weather when not
struct HoverView: View {
    @ObservedObject var store: IslandStore
    @EnvironmentObject var weatherService: QWeatherService
    @EnvironmentObject var musicService: SystemMusicService

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if musicService.hasMedia {
                musicSection
            } else {
                weatherSection
            }

            Spacer(minLength: Theme.Spacing.sm)

            controlButtons
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Music Section

    private var musicSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Album art
            if let artwork = musicService.info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .cornerRadius(Theme.Radius.sm)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(Color.fillSubtle)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 18))
                            .foregroundColor(.textQuaternary)
                    )
            }

            // Song info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(musicService.info.title)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(musicService.info.artist)
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }
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

            if !weatherService.weather.locationDisplay.isEmpty {
                Text(weatherService.weather.locationDisplay)
                    .font(.system(size: Theme.FontSize.caption2, weight: .regular))
                    .foregroundColor(.textTertiary)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Previous track
            MusicIconButton(
                systemName: "backward.fill",
                size: 11,
                action: { musicService.previousTrack() }
            )

            // Play/Pause (larger)
            MusicIconButton(
                systemName: musicService.info.isPlaying ? "pause.fill" : "play.fill",
                size: 14,
                isActive: true,
                action: { musicService.togglePlay() }
            )

            // Next track
            MusicIconButton(
                systemName: "forward.fill",
                size: 11,
                action: { musicService.nextTrack() }
            )
        }
    }
}

// MARK: - Music Icon Button

/// Polished music control button with hover effect
struct MusicIconButton: View {
    let systemName: String
    var size: CGFloat = 12
    var isActive: Bool = false
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: isActive ? 32 : 28, height: isActive ? 32 : 28)
                .background(
                    Circle()
                        .fill(backgroundFill)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if isActive {
            return .white
        }
        return .white.opacity(isHovering ? 0.9 : 0.65)
    }

    private var backgroundFill: Color {
        if isActive {
            return .white.opacity(isHovering ? 0.25 : 0.15)
        }
        return .white.opacity(isHovering ? 0.15 : 0.08)
    }
}
