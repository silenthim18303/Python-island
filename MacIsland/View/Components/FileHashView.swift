//
//  FileHashView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import CryptoKit

// MARK: - File Hash View

/// 文件哈希校验视图
struct FileHashView: View {
    @State private var filePath = ""
    @State private var hashResults: [HashAlgorithm: String] = [:]
    @State private var isComputing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 文件选择
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "doc")
                    .foregroundColor(.textTertiary)
                TextField("拖拽文件或点击选择...", text: $filePath)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textPrimary)
                    .autocorrectionDisabled()

                Button {
                    selectFile()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            if isComputing {
                ProgressView("计算中...")
                    .controlSize(.small)
                    .foregroundColor(.textSecondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.red.opacity(0.7))
            }

            // 哈希结果
            if !hashResults.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(HashAlgorithm.allCases, id: \.self) { algo in
                        if let hash = hashResults[algo] {
                            hashRow(algorithm: algo, hash: hash)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hash Row

    private func hashRow(algorithm: HashAlgorithm, hash: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(algorithm.displayName)
                    .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                    .foregroundColor(.textTertiary)
                Text(hash)
                    .font(.system(size: Theme.FontSize.caption2, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        }
        .buttonStyle(.plain)
        .help("点击复制")
    }

    // MARK: - File Selection

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        IslandStore.isPanelPresented = true
        let result = panel.runModal()
        IslandStore.isPanelPresented = false

        guard result == .OK, let url = panel.url else { return }
        filePath = url.path
        computeHashes(for: url)
    }

    // MARK: - Hash Computation

    private func computeHashes(for url: URL) {
        isComputing = true
        hashResults = [:]
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else {
                await MainActor.run {
                    isComputing = false
                    errorMessage = "无法读取文件"
                }
                return
            }

            var results: [HashAlgorithm: String] = [:]
            for algo in HashAlgorithm.allCases {
                let hash: String
                switch algo {
                case .md5: hash = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
                case .sha1: hash = Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
                case .sha256: hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                case .sha512: hash = SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
                }
                results[algo] = hash
            }

            await MainActor.run {
                hashResults = results
                isComputing = false
            }
        }
    }
}

// MARK: - Hash Algorithm

private enum HashAlgorithm: String, CaseIterable {
    case md5, sha1, sha256, sha512

    var displayName: String { rawValue.uppercased() }
}
