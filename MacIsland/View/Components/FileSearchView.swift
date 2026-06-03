//
//  FileSearchView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - File Search View

/// 本地文件搜索视图
struct FileSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchDepth: Int = 5
    @State private var fileExtension = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 搜索输入
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textTertiary)
                TextField("搜索文件名...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(.textPrimary)
                    .onSubmit { performSearch() }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button { performSearch() } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(searchText.isEmpty ? .textQuaternary : .white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(searchText.isEmpty)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            // 筛选选项
            HStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 4) {
                    Text("深度")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)
                    Picker("", selection: $searchDepth) {
                        Text("2").tag(2)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("20").tag(20)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 50)
                }

                TextField("扩展名", text: $fileExtension)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.textSecondary)
                    .frame(width: 80)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))

                Spacer()

                if !searchResults.isEmpty {
                    Text("\(searchResults.count) 个结果")
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)
                }
            }

            // 搜索结果
            if searchResults.isEmpty && !isSearching {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(searchResults) { result in
                            resultRow(result)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "folder")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.1))
            Text("输入文件名开始搜索")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Result Row

    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            NSWorkspace.shared.selectFile(result.path, inFileViewerRootedAtPath: "")
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: result.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 14))
                    .foregroundColor(result.isDirectory ? .blue : .textTertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.name)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text(result.path)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textQuaternary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(.textQuaternary)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        searchResults = []

        Task.detached(priority: .userInitiated) {
            let results = Self.searchFiles(
                query: query,
                depth: searchDepth,
                extension: fileExtension.trimmingCharacters(in: .whitespacesAndNewlines),
                searchPath: FileManager.default.homeDirectoryForCurrentUser
            )
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    private static func searchFiles(query: String, depth: Int, extension ext: String, searchPath: URL) -> [SearchResult] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: searchPath,
                                            includingPropertiesForKeys: [.isDirectoryKey],
                                            options: [.skipsHiddenFiles]) else { return [] }

        var results: [SearchResult] = []
        var currentDepth = 0
        var depthStack: [Int] = []

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent

            // 深度控制
            let pathComponents = url.pathComponents
            if pathComponents.count > depth + searchPath.pathComponents.count {
                enumerator.skipDescendants()
                continue
            }

            // 扩展名过滤
            if !ext.isEmpty && !name.lowercased().hasSuffix(".\(ext.lowercased())") {
                continue
            }

            // 名称匹配
            if name.localizedCaseInsensitiveContains(query) {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                results.append(SearchResult(
                    name: name,
                    path: url.path,
                    isDirectory: isDir
                ))
            }

            if results.count >= 100 { break }
        }

        return results
    }
}

// MARK: - SearchResult

private struct SearchResult: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
}
