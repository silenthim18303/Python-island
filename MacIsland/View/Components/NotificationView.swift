//
//  NotificationView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Notification View

/// 通知态视图
struct NotificationView: View {
    let title: String
    let notificationBody: String
    let url: String?
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // 通知图标
            Image(systemName: url != nil ? "link.circle.fill" : "bell.fill")
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(url != nil ? .green.opacity(0.6) : .blue.opacity(0.6)))

            // 通知内容
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Text(notificationBody)
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.sm)

            // 打开链接按钮
            if let url, let linkURL = URL(string: url) {
                Button {
                    NSWorkspace.shared.open(linkURL)
                    store.setIdle()
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.green))
                }
                .buttonStyle(.plain)
            }

            // 关闭按钮
            Button { store.setIdle() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.textTertiary)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}
