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
                TextField(L10n.fileHashSelect, text: $filePath)
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
                ProgressView(L10n.fileHashComputing)
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
        .help(L10n.fileHashClickCopy)
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
            do {
                let results = try Self.computeStreamingHashes(for: url)
                await MainActor.run {
                    hashResults = results
                    isComputing = false
                }
            } catch {
                await MainActor.run {
                    isComputing = false
                    errorMessage = L10n.error
                }
            }
        }
    }

    nonisolated private static func computeStreamingHashes(for url: URL) throws -> [HashAlgorithm: String] {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }

        let chunkSize = 1024 * 1024
        var md5 = Insecure.MD5()
        var sha1 = Insecure.SHA1()
        var sha256 = SHA256()
        var sha512 = SHA512()

        while true {
            guard let chunk = try file.read(upToCount: chunkSize), !chunk.isEmpty else { break }
            md5.update(data: chunk)
            sha1.update(data: chunk)
            sha256.update(data: chunk)
            sha512.update(data: chunk)
        }

        return [
            .md5: hexDigest(md5.finalize()),
            .sha1: hexDigest(sha1.finalize()),
            .sha256: hexDigest(sha256.finalize()),
            .sha512: hexDigest(sha512.finalize())
        ]
    }

    nonisolated private static func hexDigest<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Hash Algorithm

private enum HashAlgorithm: String, CaseIterable {
    case md5, sha1, sha256, sha512

    var displayName: String { rawValue.uppercased() }
}
