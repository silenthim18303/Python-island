//
//  MusicPlaybackControls.swift
//  MacIsland
//
//  Extracted from ExpandedView.swift (old version c7a8f69)
//

import SwiftUI

// MARK: - Playback Button

/// Polished playback control button with hover/press animation
struct PlaybackButton: View {
    let systemName: String
    var size: CGFloat = 18
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
            }
            action()
        }) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: isPrimary ? 48 : 36, height: isPrimary ? 48 : 36)
                .background(
                    Circle()
                        .fill(isPrimary
                            ? Color.white.opacity(isHovering ? 0.25 : 0.15)
                            : Color.white.opacity(isHovering ? 0.15 : 0.06))
                )
                .scaleEffect(isPressed ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
    }
}

// MARK: - Toggle Button

/// Toggle button for shuffle/repeat with active state
struct MusicToggleButton: View {
    let systemName: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    isActive
                        ? .accentColor
                        : .white.opacity(isHovering ? 0.6 : 0.35)
                )
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isActive
                            ? Color.accentColor.opacity(isHovering ? 0.2 : 0.1)
                            : Color.white.opacity(isHovering ? 0.1 : 0.05))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
    }
}

// MARK: - Draggable Progress View

/// 可拖拽的播放进度条
struct DraggableProgressView: View {
    let progress: Double
    let elapsed: String
    let duration: String
    let totalDuration: TimeInterval
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragFraction: Double = 0

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let trackHeight: CGFloat = 4

                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                        .frame(height: trackHeight)

                    // 已播放部分
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: width * currentFraction, height: trackHeight)

                    // 拖拽手柄
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .offset(x: width * currentFraction - 6)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
                .frame(height: trackHeight)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().size(CGSize(width: width, height: 20)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(value.location.x / width, 0), 1)
                            dragFraction = fraction
                        }
                        .onEnded { value in
                            let fraction = min(max(value.location.x / width, 0), 1)
                            onSeek(fraction)
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(isDragging ? formatDragTime(dragFraction) : elapsed)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                Text(duration)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var currentFraction: Double {
        isDragging ? dragFraction : progress
    }

    private func formatDragTime(_ fraction: Double) -> String {
        let totalSeconds = Int(fraction * totalDuration)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

// MARK: - Volume Control View

/// 音量控制滑块
struct VolumeControlView: View {
    let volume: Float
    let onVolumeChange: (Float) -> Void

    @State private var isDragging = false
    @State private var dragVolume: Float = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 16)

            GeometryReader { geometry in
                let width = geometry.size.width
                let trackHeight: CGFloat = 3

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.15))
                        .frame(height: trackHeight)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.7))
                        .frame(width: width * CGFloat(currentVolume), height: trackHeight)
                }
                .frame(height: trackHeight)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle().size(CGSize(width: width, height: 16)))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(Float(value.location.x / width), 0), 1)
                            dragVolume = fraction
                            onVolumeChange(fraction)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 16)

            Text("\(Int(currentVolume * 100))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var currentVolume: Float {
        isDragging ? dragVolume : volume
    }

    private var volumeIcon: String {
        if currentVolume <= 0 { return "speaker.slash.fill" }
        if currentVolume < 0.33 { return "speaker.wave.1.fill" }
        if currentVolume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
