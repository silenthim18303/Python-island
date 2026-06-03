//
//  ToolboxView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Toolbox View

/// 工具箱主视图 — 包含多个工具子标签
struct ToolboxView: View {
    @State private var selectedTool: Tool?

    enum Tool: String, CaseIterable, Identifiable {
        case fileSearch = "文件搜索"
        case clipboard = "剪贴板"
        case fileHash = "文件哈希"
        case encoding = "编码转换"
        case translate = "翻译"
        case mokugyo = "木鱼"
        case breakReminder = "久坐提醒"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .fileSearch: return "magnifyingglass"
            case .clipboard: return "doc.on.clipboard"
            case .fileHash: return "hash"
            case .encoding: return "character.textbox"
            case .translate: return "globe"
            case .mokugyo: return "circle.inset.filled"
            case .breakReminder: return "figure.seated.side.right"
            }
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if selectedTool == nil {
                toolGrid
            } else {
                toolHeader
                toolContent
            }
        }
    }

    // MARK: - Tool Grid

    private var toolGrid: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("工具箱")
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)
                .padding(.top, Theme.Spacing.sm)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                ForEach(Tool.allCases) { tool in
                    toolCard(tool)
                }
            }
        }
    }

    private func toolCard(_ tool: Tool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTool = tool
            }
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: tool.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.textSecondary)
                    .frame(height: 28)

                Text(tool.rawValue)
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Color.fillSubtle))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tool Header

    private var toolHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { selectedTool = nil }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let tool = selectedTool {
                Image(systemName: tool.icon)
                    .font(.system(size: 14))
                Text(tool.rawValue)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
    }

    // MARK: - Tool Content

    @ViewBuilder
    private var toolContent: some View {
        switch selectedTool {
        case .fileSearch: FileSearchView()
        case .clipboard: ClipboardHistoryView()
        case .fileHash: FileHashView()
        case .encoding: EncodingConvertView()
        case .translate: TranslateView()
        case .mokugyo: MokugyoView()
        case .breakReminder: BreakReminderView()
        case nil: EmptyView()
        }
    }
}
