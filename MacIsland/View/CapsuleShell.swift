//
//  CapsuleShell.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Capsule Shell

/// 灵动岛胶囊外壳
/// 仿 NotchNookIsland：透明背景穿透点击，内容区 onHover 统一处理交互
struct CapsuleShell: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        ZStack {
            // 透明背景层 — 不接受命中测试，让点击穿透
            Color.clear.allowsHitTesting(false)

            // 内容区域 — 接受命中测试
            contentWithInteraction
        }
        .frame(width: IslandLayout.size(for: store.state).width)
        .frame(
            height: isHeightAdaptive ? nil : IslandLayout.size(for: store.state).height
        )
        .frame(
            minHeight: isHeightAdaptive ? IslandLayout.size(for: store.state).height : nil,
            alignment: .center
        )
    }

    private var isHeightAdaptive: Bool {
        IslandLayout.isHeightAdaptive(store.state)
    }

    // MARK: - Content with Interaction

    @ViewBuilder
    private var contentWithInteraction: some View {
        ZStack {
            backgroundView
            stateContent
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .clipShape(capsuleShape)
        .contentShape(capsuleShape)
        .shadow(color: .black.opacity(stateShadow.opacity), radius: stateShadow.radius, x: 0, y: stateShadow.y)
        .onHover { handleHover($0) }
        .onTapGesture { handleTap() }
    }

    // MARK: - Hover Handling

    private func handleHover(_ hovering: Bool) {
        switch store.state {
        case .idle, .lyrics, .countdown:
            if hovering { store.setHover() }

        case .hover:
            if hovering {
                store.cancelIdleTimer()
            } else {
                store.startIdleTimer(delay: 0.3)
            }

        case .expanded, .maxExpand:
            if hovering {
                store.cancelIdleTimer()
            } else {
                store.startIdleTimer(delay: 1.5)
            }

        case .notification:
            break
        }
    }

    // MARK: - Tap Handling

    private func handleTap() {
        switch store.state {
        case .idle, .lyrics, .countdown, .hover:
            store.setExpanded()
        case .notification:
            store.setIdle()
        default:
            break
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        let cornerRadius = IslandLayout.cornerRadius(for: store.state)

        switch store.state {
        case .idle:
            Color.black
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(Theme.FillOpacity.hairline), lineWidth: 0.5)
                )

        case .hover, .expanded, .maxExpand:
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(Theme.FillOpacity.strong), lineWidth: 0.5)
                )

        case .notification:
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(Theme.FillOpacity.hairline), lineWidth: 0.5)
                )

        case .lyrics, .countdown:
            Color.black.opacity(0.7)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(Theme.FillOpacity.hairline), lineWidth: 0.5)
                )
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch store.state {
        case .idle:
            IdleView(store: store)

        case .hover:
            HoverView(store: store)

        case .expanded:
            ExpandedView(store: store)

        case .maxExpand:
            MaxExpandView(store: store)

        case .notification(let title, let body):
            NotificationView(title: title, notificationBody: body, store: store)

        case .lyrics:
            LyricsView(store: store)

        case .countdown:
            CountdownCompactView(store: store)
        }
    }

    // MARK: - Shape

    private var capsuleShape: some Shape {
        let cornerRadius = IslandLayout.cornerRadius(for: store.state)

        switch store.state {
        case .idle, .lyrics, .countdown:
            return AnyShape(Capsule())
        default:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // MARK: - Shadow Config

    private struct ShadowConfig {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    private var stateShadow: ShadowConfig {
        switch store.state {
        case .idle:
            return ShadowConfig(opacity: 0.3, radius: 8, y: 2)
        case .hover, .notification:
            return ShadowConfig(opacity: 0.35, radius: 12, y: 4)
        case .expanded:
            return ShadowConfig(opacity: 0.4, radius: 16, y: 6)
        case .maxExpand:
            return ShadowConfig(opacity: 0.45, radius: 20, y: 8)
        case .lyrics, .countdown:
            return ShadowConfig(opacity: 0.25, radius: 10, y: 3)
        }
    }
}

// MARK: - Any Shape

/// 类型擦除的 Shape 包装器
struct AnyShape: Shape {
    private let pathBuilder: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Visual Effect Blur

/// NSVisualEffectView 的 SwiftUI 包装
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
