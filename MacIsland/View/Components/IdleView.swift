//
//  IdleView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI
import Combine

// MARK: - Idle View

/// 空闲态视图 — 时间 + 日期，嵌入刘海区域
struct IdleView: View {
    @ObservedObject var store: IslandStore

    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        compactLayout
            .onReceive(timer) { currentTime = $0 }
    }

    // MARK: - Compact Layout（紧凑居中：时间 + 日期）

    private var compactLayout: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 时间
            Text(timeString)
                .font(.system(size: Theme.FontSize.body, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
                .monospacedDigit()

            // 分隔点
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: 2.5, height: 2.5)

            // 日期
            Text(dateString)
                .font(.system(size: Theme.FontSize.caption, weight: .medium, design: .rounded))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Private Properties

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d EEEE"
        return formatter.string(from: currentTime)
            .replacingOccurrences(of: "星期", with: "周")
    }
}
