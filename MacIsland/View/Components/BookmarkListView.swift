//
//  BookmarkListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Bookmark List View

/// URL 书签收藏列表视图
struct BookmarkListView: View {
    @ObservedObject var store: BookmarkStore

    @State private var showAddBookmark = false
    @State private var newTitle = ""
    @State private var newURL = ""

    var body: some View {
        if store.items.isEmpty && !showAddBookmark {
            onboardingView
        } else {
            bookmarkListView
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text("URL 书签")
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text("收藏常用链接，快速访问")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)

            Button {
                showAddBookmark = true
            } label: {
                Label("添加书签", systemImage: "plus")
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

    private var bookmarkListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(store.items.count) 个书签")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showAddBookmark = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if showAddBookmark {
                addBookmarkForm
            }

            ForEach(store.items) { item in
                bookmarkRow(item)
            }
        }
    }

    // MARK: - Add Bookmark Form

    private var addBookmarkForm: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TextField("名称", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textPrimary)

            TextField("https://example.com", text: $newURL)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textSecondary)
                .autocorrectionDisabled()

            HStack {
                Button("取消") {
                    showAddBookmark = false
                    newTitle = ""
                    newURL = ""
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button("添加") {
                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    var url = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty, !url.isEmpty else { return }
                    if !url.hasPrefix("http") { url = "https://\(url)" }
                    store.addBookmark(title: title, url: url)
                    showAddBookmark = false
                    newTitle = ""
                    newURL = ""
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

    // MARK: - Bookmark Row

    private func bookmarkRow(_ item: BookmarkItem) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundColor(.textTertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(item.url)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textQuaternary)
                    .lineLimit(1)
            }

            Spacer()

            // 打开链接
            Button { store.openBookmark(item) } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)

            // 删除
            Button { store.deleteBookmark(id: item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textQuaternary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .background(Circle().fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }
}
