//
//  OnboardingView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import AppKit

// MARK: - Onboarding View

/// 首次运行引导视图（在独立全屏窗口中显示）
struct OnboardingView: View {
    @Binding var isShowing: Bool
    @State private var currentPage = 0

    private let pages: [(title: String, subtitle: String, icon: String)] = [
        ("欢迎使用 MacIsland", "你的 macOS 灵动岛助手", "island"),
        ("音乐与歌词", "自动检测播放器，同步显示歌词", "music.note"),
        ("天气与计时", "实时天气预报，番茄钟与倒计时", "cloud.sun"),
        ("工具箱", "文件搜索、剪贴板历史、哈希校验等实用工具", "wrench.and.screwdriver"),
        ("便签与书签", "快速记录想法，收藏常用链接", "bookmark.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 页面内容
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: pages[currentPage].icon)
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.bottom, Theme.Spacing.md)

                Text(pages[currentPage].title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(pages[currentPage].subtitle)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 48)

            Spacer()

            // 页码指示器
            HStack(spacing: 10) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 10 : 7,
                               height: index == currentPage ? 10 : 7)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, Theme.Spacing.xl)

            // 操作按钮
            HStack(spacing: Theme.Spacing.lg) {
                if currentPage > 0 {
                    Button("上一步") {
                        withAnimation { currentPage -= 1 }
                    }
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)
                }

                Spacer()

                if currentPage < pages.count - 1 {
                    Button("下一步") {
                        withAnimation { currentPage += 1 }
                    }
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .buttonStyle(.plain)
                } else {
                    Button("开始使用") {
                        complete()
                    }
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 24)

            // 跳过
            Button("跳过") { complete() }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.white.opacity(0.3))
                .buttonStyle(.plain)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation { isShowing = false }
    }
}

// MARK: - Onboarding Window Manager

/// 管理引导页独立窗口
@MainActor
final class OnboardingWindowManager {
    static let shared = OnboardingWindowManager()

    private var window: NSWindow?
    @State private var isShowing = false

    private init() {}

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        guard window == nil else { return }

        let contentView = OnboardingView(isShowing: $isShowing)
            .onChange(of: isShowing) { _, showing in
                if !showing { self.dismiss() }
            }

        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.backgroundColor = .black
        window.level = .screenSaver
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.orderFrontRegardless()

        self.window = window
        self.isShowing = true
    }

    func dismiss() {
        window?.close()
        window = nil
        isShowing = false
    }
}
