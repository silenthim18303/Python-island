//
//  ClipboardHistoryView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Clipboard History View

/// 剪贴板历史记录视图
struct ClipboardHistoryView: View {
    @State private var history: [ClipboardEntry] = []
    @State private var pollTimer: Timer?
    @State private var maxHistory = 50

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(history.count) \(L10n.clipboardRecords)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                if !history.isEmpty {
                    Button {
                        history.removeAll()
                    } label: {
                        Text(L10n.clear)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            if history.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(history) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.1))
            Text(L10n.clipboardEmpty)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: ClipboardEntry) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.text, forType: .string)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.text)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    Text(entry.timestamp, style: .time)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textQuaternary)
                }

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.textQuaternary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Polling

    private func startPolling() {
        var lastText = NSPasteboard.general.string(forType: .string) ?? ""
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let current = NSPasteboard.general.string(forType: .string) ?? ""
            if !current.isEmpty && current != lastText {
                lastText = current
                let entry = ClipboardEntry(text: current)
                DispatchQueue.main.async {
                    history.insert(entry, at: 0)
                    if history.count > maxHistory {
                        history = Array(history.prefix(maxHistory))
                    }
                    // 同步到小组件
                    Self.syncToWidget(history)
                }
            }
        }
    }

    /// 同步剪贴板历史到小组件
    private static func syncToWidget(_ history: [ClipboardEntry]) {
        let items = history.prefix(5).map { entry -> [String: Any] in
            [
                "id": entry.id.uuidString,
                "text": entry.text,
                "timestamp": entry.timestamp.timeIntervalSince1970
            ]
        }
        WidgetDataManager.shared.updateClipboard(items: items)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - ClipboardEntry

private struct ClipboardEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp = Date()
}
