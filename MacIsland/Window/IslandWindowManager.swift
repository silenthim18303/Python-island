//
//  IslandWindowManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Activatable Panel

/// 支持键盘输入的 NSPanel — 在需要时可以成为 key window
private class ActivatablePanel: NSPanel {
    var canBecomeKeyCustom = false

    override var canBecomeKey: Bool { canBecomeKeyCustom }
    override var canBecomeMain: Bool { false }

    /// 每次鼠标按下时通知管理器，用于防止输入时误收起
    override func mouseDown(with event: NSEvent) {
        IslandWindowManager.shared.onMouseDown()
        super.mouseDown(with: event)
    }

    /// 每次键盘输入时通知管理器
    override func keyDown(with event: NSEvent) {
        IslandWindowManager.shared.onKeyDown()
        super.keyDown(with: event)
    }
}

// MARK: - No-op Hosting View

/// 子类化 NSHostingView，拦截 setFrameSize 防止布局递归
/// 使用非泛型子类避免 Swift 6.3.2 优化器崩溃
private final class NoAutoResizeHostingView: NSHostingView<AnyView> {
    var blockResize = true

    override func setFrameSize(_ newSize: NSSize) {
        if !blockResize {
            super.setFrameSize(newSize)
        }
        // blockResize 为 true 时完全忽略 SwiftUI 的自动尺寸调整
    }
}

// MARK: - Island Window Manager

/// 灵动岛窗口管理器
/// 定位逻辑：使用 visibleFrame，idle 胶囊顶部贴屏幕物理顶部
final class IslandWindowManager {
    static let shared = IslandWindowManager()

    private var panel: NSPanel?
    private var hostingView: NoAutoResizeHostingView?
    private var currentState: IslandState = .idle
    private var lastAdaptiveHeight: CGFloat = 0
    private var isResizing = false
    private var cancellables = Set<AnyCancellable>()

    /// 最近一次鼠标点击/键盘输入时间，用于防止输入时误触空闲收起
    private(set) var lastInteraction: Date = .distantPast

    /// 鼠标按下时调用
    func onMouseDown() {
        lastInteraction = Date()
    }

    /// 键盘按下时调用
    func onKeyDown() {
        lastInteraction = Date()
    }

    /// 折叠回调 — 由 IslandView 注册，菜单调用 collapse() 时触发岛回到 idle
    var onCollapse: (() -> Void)?

    /// 设置窗口透明度 (0.0 ~ 1.0)
    func setOpacity(_ opacity: Double) {
        panel?.alphaValue = CGFloat(opacity)
    }

    /// 临时降低窗口层级（用于弹出文件选择器等系统面板）
    func temporarilyLowerLevel() {
        panel?.level = .normal
    }

    /// 恢复窗口层级
    func restoreLevel() {
        panel?.level = .statusBar
    }

    /// 获取灵动岛窗口（用于附加 Sheet）
    var islandWindow: NSWindow? { panel }

    private init() {}

    // MARK: - Window Lifecycle

    func createWindow<Content: View>(content: Content) {
        guard panel == nil else { return }

        let size = IslandLayout.idle
        let frame = calculateFrame(for: size, state: .idle)

        let panel = ActivatablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel(panel, with: size)
        let hv = configureContentView(panel, with: content, size: size)
        self.hostingView = hv

        panel.orderFrontRegardless()
        self.panel = panel
        self.currentState = .idle

        // 窗口显示后阻止 SwiftUI 自动调整
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            hv.blockResize = true
        }

        // 实时订阅透明度变化，确保滑块拖动即时生效
        AppSettings.shared.$islandOpacity
            .removeDuplicates()
            .sink { [weak self] opacity in
                self?.panel?.alphaValue = CGFloat(opacity)
            }
            .store(in: &cancellables)
    }

    func resize(to size: CGSize, state: IslandState, animated: Bool = true) {
        guard let panel = panel else { return }
        let stateChanged = currentState != state
        currentState = state
        if stateChanged { lastAdaptiveHeight = 0 }

        // 只在状态真正变化时切换 canBecomeKey，避免触发约束递归
        if stateChanged {
            let needsKey: Bool
            switch state {
            case .expanded, .maxExpand: needsKey = true
            default: needsKey = false
            }
            if let activatable = panel as? ActivatablePanel {
                activatable.canBecomeKeyCustom = needsKey
            }
        }

        // 自适应态：宽度固定，高度沿用上次测量值（由 updateHeight 驱动），避免在此重置高度
        let effectiveSize = IslandLayout.isHeightAdaptive(state)
            ? CGSize(width: size.width, height: max(size.height, lastAdaptiveHeight))
            : size

        let newFrame = calculateFrame(for: effectiveSize, state: state)
        let cornerRadius = IslandLayout.cornerRadius(for: state)

        hostingView?.blockResize = false
        if animated {
            let duration = AppSettings.shared.animationSpeed.duration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            } completionHandler: { [weak self] in
                self?.hostingView?.blockResize = true
            }
        } else {
            panel.setFrame(newFrame, display: true)
            hostingView?.blockResize = true
        }

        panel.contentView?.layer?.cornerRadius = cornerRadius
    }

    /// 自适应态内容高度变化时调用 — 仅在当前态为自适应时生效
    func updateHeight(_ height: CGFloat) {
        guard let panel = panel, IslandLayout.isHeightAdaptive(currentState) else { return }
        // 防止 resize 触发的重绘再次调用 updateHeight，形成无限循环
        guard !isResizing else { return }
        let width = IslandLayout.size(for: currentState).width
        let clamped = max(IslandLayout.size(for: currentState).height, height)
        // 高度变化小于 2pt 时跳过，避免微小抖动触发窗口调整
        guard abs(clamped - lastAdaptiveHeight) > 2 else { return }
        lastAdaptiveHeight = clamped

        let newFrame = calculateFrame(for: CGSize(width: width, height: clamped), state: currentState)
        isResizing = true
        hostingView?.blockResize = false
        panel.setFrame(newFrame, display: true)
        hostingView?.blockResize = true
        isResizing = false
    }

    // MARK: - Visibility

    func show() {
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    /// 折叠岛回到 idle 态
    func collapse() {
        onCollapse?()
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    var isKeyWindow: Bool {
        panel?.isKeyWindow ?? false
    }

    func destroy() {
        panel?.close()
        panel = nil
    }

    // MARK: - Private Configuration

    private func configurePanel(_ panel: NSPanel, with size: CGSize) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .transient]
    }

    @discardableResult
    private func configureContentView<Content: View>(_ panel: NSPanel, with content: Content, size: CGSize) -> NoAutoResizeHostingView {
        let hostingView = NoAutoResizeHostingView(rootView: AnyView(content))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.blockResize = false // 初始阶段允许设置尺寸

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = IslandLayout.cornerRadius(for: .idle)
        panel.contentView?.layer?.masksToBounds = true
        return hostingView
    }

    // MARK: - Frame Calculation

    private func calculateFrame(for size: CGSize, state: IslandState) -> CGRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let x = visibleFrame.midX - size.width / 2
        let screenTop = screenFrame.maxY      // 屏幕物理顶端（含刘海区）
        let notchBottom = visibleFrame.maxY   // 可见区顶端 = 刘海底部

        // 各形态垂直定位（macOS 坐标系 y 向上，故用顶端减去高度得到底边 y）
        let y: CGFloat
        switch state {
        case .idle, .lyrics, .countdown:
            // 缩小态：贴物理顶端后再下移一个刘海高度，落在刘海正下方
            y = screenTop - size.height - NotchInfo.height
        case .hover, .notification:
            // 速览/通知态：紧贴刘海底部展开
            y = notchBottom - size.height
        case .expanded:
            // 展开态：贴刘海底部，留 2pt 视觉间隙
            y = notchBottom - size.height - 2
        case .maxExpand:
            // 最大展开态：面板更大，留 4pt 间隙更协调
            y = notchBottom - size.height - 4
        }

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
