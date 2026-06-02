//
//  MaxExpandView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Max Expand View

/// 最大展开态视图 — 待办/AI/设置/工具
struct MaxExpandView: View {
    @ObservedObject var store: IslandStore
    @State private var selectedTab: Tab = .todo

    // MARK: - Tab Definition

    enum Tab: String, CaseIterable {
        case todo = "待办"
        case ai = "AI"
        case settings = "设置"
        case toolbox = "工具"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerBar

            // Tab 选择器
            tabBar

            // 内容区
            ScrollView {
                tabContent
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("MacIsland")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // 收起按钮
            Button { store.setExpanded() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)

            // 关闭按钮
            Button { store.setIdle() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 14))

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle)
                            : nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .todo: todoContent
        case .ai: aiContent
        case .settings: settingsContent
        case .toolbox: toolboxContent
        }
    }

    // MARK: - Todo Content

    private var todoContent: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: 10) {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    Text("示例待办事项 #\(index + 1)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - AI Content

    private var aiContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            Text("AI 助手")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            Text("集成 Claude / DeepSeek 等 AI 模型\n支持对话、工具调用、语音输入")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            SettingsLink {
                Text("打开设置")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Toolbox Content

    private var toolboxContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            Text("工具箱")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))

            Text("截图、剪贴板历史、格式转换\n系统监控等功能即将推出")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helper

    private func iconName(for tab: Tab) -> String {
        switch tab {
        case .todo: return "checklist"
        case .ai: return "brain.head.profile"
        case .settings: return "gearshape.fill"
        case .toolbox: return "wrench.and.screwdriver.fill"
        }
    }
}

