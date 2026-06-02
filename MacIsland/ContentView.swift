//
//  ContentView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import SwiftUI

// MARK: - Content View

/// 主内容视图 — 作为 IslandView 的 SwiftUI 容器
struct ContentView: View {
    var body: some View {
        IslandView()
            .background(Color.clear)
    }
}
