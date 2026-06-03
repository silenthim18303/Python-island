//
//  MokugyoView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Mokugyo View

/// 木鱼冥想组件 — 点击敲击木鱼，显示计数与波纹动画
struct MokugyoView: View {
    @State private var tapCount: Int = 0
    @State private var ripples: [Ripple] = []
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 标题
            Text("木鱼冥想")
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text("静心敲击，放松身心")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            // 木鱼主体
            ZStack {
                // 波纹效果
                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(ripple.color.opacity(ripple.opacity), lineWidth: 2)
                        .frame(width: ripple.radius, height: ripple.radius)
                }

                // 木鱼图标
                Button {
                    tap()
                } label: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.brown.opacity(0.8))
                        .overlay(
                            Image(systemName: "circle.inset.filled")
                                .font(.system(size: 40))
                                .foregroundColor(.brown.opacity(0.4))
                        )
                        .scaleEffect(scale)
                        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 120)

            // 计数
            VStack(spacing: 4) {
                Text("\(tapCount)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("次敲击")
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textQuaternary)
            }

            // 操作按钮
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    withAnimation { tapCount = 0 }
                } label: {
                    Text("重置")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(tapCount)", forType: .string)
                } label: {
                    Text("复制计数")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)
                .disabled(tapCount == 0)
            }
        }
    }

    // MARK: - Tap Action

    private func tap() {
        tapCount += 1

        // 敲击动画
        withAnimation(.easeOut(duration: 0.15)) {
            scale = 0.92
        }
        withAnimation(.easeIn(duration: 0.15).delay(0.15)) {
            scale = 1.0
        }
        withAnimation(.easeOut(duration: 0.3)) {
            rotation = Double.random(in: -3...3)
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
            rotation = 0
        }

        // 波纹
        let ripple = Ripple(
            color: [.white, .orange, .yellow, .brown].randomElement()!,
            radius: 60,
            opacity: 0.6
        )
        ripples.append(ripple)

        // 淡出波纹
        withAnimation(.easeOut(duration: 1.0)) {
            if let index = ripples.firstIndex(where: { $0.id == ripple.id }) {
                ripples[index].radius = 140
                ripples[index].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - Ripple

private struct Ripple: Identifiable {
    let id = UUID()
    let color: Color
    var radius: CGFloat
    var opacity: Double
}
