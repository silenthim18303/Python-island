//
//  MarqueeText.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

// MARK: - Marquee Text

/// 自动滚动的跑马灯文本 — 文本超出容器宽度时，水平来回滚动显示
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating = false

    /// 文本首尾停留时间（秒）
    private let pauseDuration: TimeInterval = 2.0
    /// 滚动速度（pt/秒）
    private let scrollSpeed: CGFloat = 30

    var body: some View {
        GeometryReader { containerGeo in
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear
                            .preference(key: TextWidthKey.self, value: textGeo.size.width)
                    }
                )
                .offset(x: offset)
                .onPreferenceChange(TextWidthKey.self) { newWidth in
                    textWidth = newWidth
                    containerWidth = containerGeo.size.width
                    restartAnimationIfNeeded()
                }
                .onAppear {
                    containerWidth = containerGeo.size.width
                    restartAnimationIfNeeded()
                }
                .onChange(of: text) { _, _ in
                    // 歌词切换时重置偏移
                    offset = 0
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        restartAnimationIfNeeded()
                    }
                }
        }
        .clipped()
        .frame(maxWidth: .infinity)
    }

    private func restartAnimationIfNeeded() {
        guard !isAnimating, textWidth > containerWidth + 4 else {
            // 文本未溢出，居中显示
            offset = 0
            return
        }
        isAnimating = true
        startMarquee()
    }

    private func startMarquee() {
        let scrollDistance = textWidth - containerWidth
        let scrollDuration = TimeInterval(scrollDistance / scrollSpeed)

        // 循环：停留 → 滚到末尾 → 停留 → 滚回开头
        func cycle() {
            guard isAnimating else { return }

            // 停留在开头
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                guard isAnimating else { return }

                // 滚到末尾
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -scrollDistance
                }

                // 停留在末尾
                DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + pauseDuration) {
                    guard isAnimating else { return }

                    // 滚回开头
                    withAnimation(.linear(duration: scrollDuration)) {
                        offset = 0
                    }

                    // 继续循环
                    DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + pauseDuration) {
                        cycle()
                    }
                }
            }
        }

        cycle()
    }
}

// MARK: - Text Width Preference Key

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
