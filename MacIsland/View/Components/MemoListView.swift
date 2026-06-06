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

    @State private var showNewMemo = false
    @State private var editingId: UUID?
    @State private var editTitle = ""
    @State private var editContent = ""

    var body: some View {
        if store.sortedItems.isEmpty && !showNewMemo {
            onboardingView
        } else {
            memoListView
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
                showNewMemo = true
                editTitle = ""
                editContent = ""
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
            // 顶部操作栏
            HStack {
                Text("\(store.items.count) \(L10n.count)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showNewMemo = true
                    editTitle = ""
                    editContent = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            // 新建/编辑区
            if showNewMemo || editingId != nil {
                memoEditor
            }

            // 便签列表
            ForEach(store.sortedItems) { item in
                memoRow(item)
            }
        }
    }

    // MARK: - Editor

    private var memoEditor: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TextField(L10n.memoPlaceholder, text: $editTitle)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                .foregroundColor(.textPrimary)

            TextEditor(text: $editContent)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            HStack {
                Button(L10n.cancel) {
                    showNewMemo = false
                    editingId = nil
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button(L10n.save) {
                    saveMemo()
                }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fillSubtle))
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
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
                    editingId = item.id
                    editTitle = item.title
                    editContent = item.content
                    showNewMemo = false
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

    // MARK: - Helpers

    private func saveMemo() {
        let title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = editContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editId = editingId {
            store.updateMemo(id: editId, title: title, content: content)
            editingId = nil
        } else {
            store.addMemo(title: title, content: content)
            showNewMemo = false
        }
        editTitle = ""
        editContent = ""
    }
}
