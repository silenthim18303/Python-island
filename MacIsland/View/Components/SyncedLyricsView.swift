//
//  SyncedLyricsView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Synced Lyrics View

/// Time-synced scrolling lyrics display
struct SyncedLyricsView: View {
    let lyrics: LyricsDocument
    let elapsed: TimeInterval

    @State private var activeIndex: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top padding for centering
                    Spacer().frame(height: 40)

                    ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                        let isActive = index == activeIndex
                        let isPast = index < (activeIndex ?? 0)

                        Text(line.text)
                            .font(.system(
                                size: isActive ? Theme.FontSize.body : Theme.FontSize.caption,
                                weight: isActive ? .semibold : .regular
                            ))
                            .foregroundColor(
                                isActive
                                    ? .textPrimary
                                    : isPast
                                        ? .white.opacity(0.2)
                                        : .textTertiary
                            )
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                            .id(index)
                            .animation(.easeInOut(duration: 0.25), value: isActive)
                    }

                    // Bottom padding
                    Spacer().frame(height: 60)
                }
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)

                    Color.white

                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 20)
                }
            )
            .onChange(of: elapsed) { _, newElapsed in
                let newIndex = lyrics.activeLineIndex(at: newElapsed)
                if newIndex != activeIndex {
                    activeIndex = newIndex
                    if let index = newIndex {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
            .onAppear {
                activeIndex = lyrics.activeLineIndex(at: elapsed)
                if let index = activeIndex {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}
