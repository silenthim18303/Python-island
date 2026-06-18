//
//  CapsuleShell.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import AVKit
import Combine

// MARK: - Capsule Shell

/// 灵动岛胶囊外壳
/// 仿 NotchNookIsland：透明背景穿透点击，内容区 onHover 统一处理交互
struct CapsuleShell: View {
    @ObservedObject var store: IslandStore
    @ObservedObject private var wallpaperStore = WallpaperStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var timerService: TimerService
    @EnvironmentObject var musicService: MusicService
    @EnvironmentObject var lyricsService: LyricsService
    @State private var isDragOver = false
    @State private var lastSyncedSize: CGSize = .zero
    /// SwiftUI 实际渲染的尺寸（延迟同步，与 NSPanel 动画对齐）
    @State private var displaySize: CGSize = IslandLayout.size(for: .idle)

    var body: some View {
        ZStack {
            Color.clear.allowsHitTesting(false)
            contentWithInteraction
        }
        .frame(width: displaySize.width, height: isHeightAdaptive ? nil : displaySize.height)
        .frame(minHeight: isHeightAdaptive ? displaySize.height : nil, alignment: .center)
        .onAppear {
            displaySize = currentSize
            lastSyncedSize = currentSize
            DispatchQueue.main.async {
                IslandWindowManager.shared.resize(to: currentSize, state: store.state, animated: false)
            }
        }
        .onReceive(store.$state) { _ in syncWindowSize() }
    }

    private var isHeightAdaptive: Bool {
        IslandLayout.isHeightAdaptive(store.state)
    }

    /// 当前窗口尺寸 — 各状态严格固定
    private var currentSize: CGSize {
        IslandLayout.size(for: store.state)
    }

    private func syncWindowSize() {
        let size = currentSize
        guard size != lastSyncedSize else { return }
        lastSyncedSize = size
        // NSPanel 动画
        DispatchQueue.main.async {
            IslandWindowManager.shared.resize(to: size, state: self.store.state, animated: true)
        }
        // SwiftUI 帧同步动画（与面板动画对齐）
        let duration = AppSettings.shared.animationSpeed.duration
        withAnimation(.easeInOut(duration: duration)) {
            displaySize = size
        }
    }

    // MARK: - Content with Interaction

    @ViewBuilder
    private var contentWithInteraction: some View {
        let size = displaySize
        ZStack {
            // 背景遮罩（有壁纸时换为半透明暗色）
            backgroundView
            // 壁纸层 — 精确约束到胶囊尺寸，防止图片溢出推走工具栏
            wallpaperLayer
                .allowsHitTesting(false)
                .opacity(settings.wallpaperOpacity)
                .frame(width: size.width, height: size.height)
                .scaledToFill()
                .clipped()
            // UI 内容最上层
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
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { _ in true }
        .onTapGesture { handleTap() }
    }

    // MARK: - Hover Handling

    private func handleHover(_ hovering: Bool) {
        if isDragOver { return }

        if store.state.isCompact {
            if hovering { store.setHover() }
            return
        }

        switch store.state {
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
                let recentlyInteracted = Date().timeIntervalSince(IslandWindowManager.shared.lastInteraction) < 2.0
                if IslandWindowManager.shared.isKeyWindow || store.isSheetPresented || store.isPanelPresented || recentlyInteracted {
                    return
                }
                store.startIdleTimer(delay: 1.5)
            }

        case .notification:
            break

        default:
            break
        }
    }

    // MARK: - Tap Handling

    private func handleTap() {
        if store.state.isCompact {
            store.setExpanded()
            return
        }

        switch store.state {
        case .hover:
            store.setExpanded()
        case .notification(_, _, let url):
            if let url, let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
            store.setIdle()
        default:
            break
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        let cornerRadius = IslandLayout.cornerRadius(for: store.state)

        if store.state.isCompact {
            let baseOpacity = wallpaperStore.activeWallpaper == nil ? 0.78 : 0.58
            // 所有缩小态：深色材质底 + 细描边，壁纸存在时保留一点透出感
            Rectangle()
                .fill(Color.black.opacity(baseOpacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.13),
                            Color.white.opacity(0.02),
                            Color.black.opacity(0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.16), lineWidth: 0.5)
                )
        } else {
            switch store.state {
            case .hover, .expanded, .maxExpand:
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .overlay(Color.black.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(Theme.FillOpacity.strong), lineWidth: 0.5)
                    )

            case .notification:
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .overlay(Color.black.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(Theme.FillOpacity.hairline), lineWidth: 0.5)
                    )

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Wallpaper Layer

    @ViewBuilder
    private var wallpaperLayer: some View {
        if let wallpaper = wallpaperStore.activeWallpaper,
           wallpaper.fileExists {
            if wallpaper.isVideo {
                VideoWallpaperView(url: wallpaper.fileURL!)
                    .scaledToFill()
            } else {
                WallpaperImageView(url: wallpaper.fileURL!)
                    .scaledToFill()
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        if store.state.isCompact {
            IdleView()
        } else {
            switch store.state {
            case .hover:
                HoverView()

            case .expanded:
                ExpandedView(store: store)

            case .maxExpand:
                MaxExpandView(store: store)

            case .notification(let title, let body, let url):
                NotificationView(title: title, notificationBody: body, url: url, store: store)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Shape

    private var capsuleShape: some Shape {
        let cornerRadius = IslandLayout.cornerRadius(for: store.state)

        if store.state.isCompact {
            return AnyShape(Capsule())
        }
        return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Shadow Config

    private struct ShadowConfig {
        let opacity: Double
        let radius: CGFloat
        let y: CGFloat
    }

    private var stateShadow: ShadowConfig {
        if store.state.isCompact {
            switch store.state {
            case .idle, .idleClock1, .idleClock2, .idleClock1Clock2:
                return ShadowConfig(opacity: 0.3, radius: 8, y: 2)
            default:
                return ShadowConfig(opacity: 0.35, radius: 10, y: 3)
            }
        }

        switch store.state {
        case .hover, .notification:
            return ShadowConfig(opacity: 0.35, radius: 12, y: 4)
        case .expanded:
            return ShadowConfig(opacity: 0.4, radius: 16, y: 6)
        case .maxExpand:
            return ShadowConfig(opacity: 0.45, radius: 20, y: 8)
        default:
            return ShadowConfig(opacity: 0.35, radius: 10, y: 3)
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

// MARK: - Video Wallpaper View

/// 动态视频壁纸
struct VideoWallpaperView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspectFill

        // 循环播放 — 存储 observer token 以便清理
        let token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        context.coordinator.observerToken = token

        player.play()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ nsView: AVPlayerView, coordinator: Coordinator) {
        if let token = coordinator.observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    class Coordinator {
        var observerToken: NSObjectProtocol?
    }
}

// MARK: - Wallpaper Image View

/// 异步加载 + 缓存壁纸图片，避免全分辨率加载卡死
struct WallpaperImageView: View {
    let url: URL
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                Color.clear
            }
        }
        .onAppear { loadResized() }
        .onChange(of: url) { _, _ in loadResized() }
    }

    private func loadResized() {
        isLoading = true
        let targetURL = url

        // 缓存 key = 文件路径 + 修改时间
        let cacheKey = "\(targetURL.path)_resized"
        if let cached = ImageCache.shared.get(cacheKey) {
            image = cached
            isLoading = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGImageSourceCreateWithURL(targetURL as CFURL, nil) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            // 目标尺寸：窗口最大 660pt，2x 分辨率 = 1320px
            let maxDimension: CGFloat = 1320
            let downsampleOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            let resized = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            ImageCache.shared.set(cacheKey, image: resized)

            DispatchQueue.main.async {
                image = resized
                isLoading = false
            }
        }
    }
}

// MARK: - Image Cache

/// 简单内存图片缓存
final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    private init() {
        cache.countLimit = 5
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }

    func get(_ key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ key: String, image: NSImage) {
        cache.setObject(image, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
