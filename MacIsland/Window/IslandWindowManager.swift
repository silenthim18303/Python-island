//
//  IslandWindowManager.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import AppKit

// MARK: - Activatable Panel

/// 支持键盘输入的 NSPanel — 在需要时可以成为 key window
private class ActivatablePanel: NSPanel {
    var canBecomeKeyCustom = false

    override var canBecomeKey: Bool { canBecomeKeyCustom }
    override var canBecomeMain: Bool { false }
}

// MARK: - Island Window Manager

/// 灵动岛窗口管理器
/// 定位逻辑：使用 visibleFrame，idle 胶囊顶部贴屏幕物理顶部
final class IslandWindowManager {
    static let shared = IslandWindowManager()

    private var panel: NSPanel?
    private var currentState: IslandState = .idle
    private var lastAdaptiveHeight: CGFloat = 0

    /// 折叠回调 — 由 IslandView 注册，菜单调用 collapse() 时触发岛回到 idle
    var onCollapse: (() -> Void)?

    /// 设置窗口透明度 (0.0 ~ 1.0)
    func setOpacity(_ opacity: Double) {
        panel?.alphaValue = CGFloat(opacity)
    }

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
        configureContentView(panel, with: content, size: size)

        panel.orderFrontRegardless()
        self.panel = panel
        self.currentState = .idle
    }

    func resize(to size: CGSize, state: IslandState, animated: Bool = true) {
        guard let panel = panel as? ActivatablePanel else { return }
        let stateChanged = currentState != state
        currentState = state
        if stateChanged { lastAdaptiveHeight = 0 }

        // 展开态/最大展开态需要键盘输入（待办、便签等），允许面板激活
        let needsKey: Bool
        switch state {
        case .expanded, .maxExpand: needsKey = true
        default: needsKey = false
        }
        panel.canBecomeKeyCustom = needsKey

        // 自适应态：宽度固定，高度沿用上次测量值（由 updateHeight 驱动），避免在此重置高度
        let effectiveSize = IslandLayout.isHeightAdaptive(state)
            ? CGSize(width: size.width, height: max(size.height, lastAdaptiveHeight))
            : size

        let newFrame = calculateFrame(for: effectiveSize, state: state)
        let cornerRadius = IslandLayout.cornerRadius(for: state)

        if animated {
            let duration = AppSettings.shared.animationSpeed.duration
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }

        panel.contentView?.layer?.cornerRadius = cornerRadius
    }

    /// 自适应态内容高度变化时调用 — 仅在当前态为自适应时生效
    func updateHeight(_ height: CGFloat) {
        guard let panel = panel, IslandLayout.isHeightAdaptive(currentState) else { return }
        let width = IslandLayout.size(for: currentState).width
        let clamped = max(IslandLayout.size(for: currentState).height, height)
        lastAdaptiveHeight = clamped

        let newFrame = calculateFrame(for: CGSize(width: width, height: clamped), state: currentState)
        let duration = AppSettings.shared.animationSpeed.duration * 0.7
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
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

    private func configureContentView<Content: View>(_ panel: NSPanel, with content: Content, size: CGSize) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = IslandLayout.cornerRadius(for: .idle)
        panel.contentView?.layer?.masksToBounds = true
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
