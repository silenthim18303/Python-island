//
//  WidgetShared.swift
//  MacIslandWidgets
//
//  Created by GeminiMortal on 2026/6/6.
//

import SwiftUI
import WidgetKit

// MARK: - Shared Constants

enum WidgetConstants {
    static let appGroupID = "group.geminimortal.MacIsland"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? UserDefaults.standard
    }
}

// MARK: - Widget Theme

enum WidgetTheme {
    static let accentColor = Color.blue
    static let secondaryColor = Color.secondary
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 12
}

// MARK: - Widget Placeholder View

struct WidgetPlaceholderView: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Widget Empty State

struct WidgetEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
