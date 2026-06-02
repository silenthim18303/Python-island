//
//  WideNotchLayout.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/2.
//

import SwiftUI

// MARK: - Wide Notch Layout

/// 横向绕刘海布局容器 — 左侧内容 / 让出物理刘海宽度 / 右侧内容
/// 由空闲态横向样式抽出，供歌词、倒计时等中间显示事项复用
struct WideNotchLayout<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: IslandLayout.wideSideWidth, alignment: .trailing)
                .padding(.trailing, Theme.Spacing.md)

            // 中间：让出物理刘海宽度
            Spacer(minLength: NotchInfo.width)

            trailing
                .frame(width: IslandLayout.wideSideWidth, alignment: .leading)
                .padding(.leading, Theme.Spacing.md)
        }
    }
}
