//
//  MemoListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Memo List View

/// 便签列表视图
struct MemoListView: View {
    @ObservedObject var store: MemoStore

    @State private var showAddSheet = false
    @State private var editingItem: MemoItem?

    var body: some View {
        Group {
            if store.sortedItems.isEmpty {
                onboardingView
            } else {
                memoListView
            }
        }
        .sheet(isPresented: $showAddSheet) {
            MemoEditorSheet(store: store, isPresented: $showAddSheet)
                .onAppear { NotificationCenter.default.post(name: .sheetPresented, object: nil) }
                .onDisappear { NotificationCenter.default.post(name: .sheetDismissed, object: nil) }
        }
        .sheet(item: $editingItem) { item in
            MemoEditorSheet(store: store, isPresented: .init(
                get: { editingItem != nil },
                set: { if !$0 { editingItem = nil } }
            ), editItem: item)
                .onAppear { NotificationCenter.default.post(name: .sheetPresented, object: nil) }
                .onDisappear { NotificationCenter.default.post(name: .sheetDismissed, object: nil) }
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text(L10n.memoTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(L10n.memoEmpty)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            Button {
                showAddSheet = true
            } label: {
                Label(L10n.add, systemImage: "plus")
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Main List

    private var memoListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(store.items.count) \(L10n.count)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            ForEach(store.sortedItems) { item in
                memoRow(item)
            }
        }
    }

    // MARK: - Memo Row

    private func memoRow(_ item: MemoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                Text(item.title.isEmpty ? L10n.noData : item.title)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            if !item.content.isEmpty {
                Text(item.content)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }

            HStack {
                Text(item.updatedAt, style: .relative)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textQuaternary)

                Spacer()

                Button { store.togglePin(id: item.id) } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundColor(item.pinned ? .orange : .textQuaternary)
                }
                .buttonStyle(.plain)

                Button {
                    editingItem = item
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.textQuaternary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { store.deleteMemo(id: item.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.textQuaternary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }
}

// MARK: - Memo Editor Sheet

/// 便签编辑 Sheet（新建/编辑共用）
struct MemoEditorSheet: View {
    @ObservedObject var store: MemoStore
    @Binding var isPresented: Bool
    var editItem: MemoItem?

    @State private var title = ""
    @State private var content = ""

    private var isEditing: Bool { editItem != nil }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 标题栏
            HStack {
                Text(isEditing ? "编辑便签" : "新建便签")
                    .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textTertiary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)
            }

            // 标题输入
            TextField("标题", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(.textPrimary)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

            // 内容输入
            TextEditor(text: $content)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

            // 按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button(isEditing ? "保存" : "添加") {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let editId = editItem?.id {
                        store.updateMemo(id: editId, title: t, content: c)
                    } else {
                        store.addMemo(title: t, content: c)
                    }
                    isPresented = false
                }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor))
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 320)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            if let item = editItem {
                title = item.title
                content = item.content
            }
        }
    }
}
