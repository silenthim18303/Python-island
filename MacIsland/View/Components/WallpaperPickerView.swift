//
//  WallpaperPickerView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Wallpaper Picker View

/// 本地文件选择器 — 支持拖拽 + 点击选择图片/视频作为壁纸
struct WallpaperPickerView: View {
    @ObservedObject var store: WallpaperStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedURL: URL?
    @State private var previewImage: NSImage?
    @State private var isVideo = false
    @State private var isDragOver = false
    @State private var fileName = ""
    @State private var fileSize = ""
    @State private var imageDimensions = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 标题栏
            headerBar

            // 预览区（支持拖拽）
            previewArea

            // 文件信息
            if selectedURL != nil {
                fileInfoBar
            }

            // 操作按钮
            actionButtons

            // 格式说明
            formatHint
        }
        .padding(Theme.Spacing.lg)
        .frame(width: 420)
        .background(Color.black.ignoresSafeArea())
        .alert(L10n.error, isPresented: $showError) {
            Button(L10n.ok) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(L10n.wallpaperSelect)
                .font(.system(size: Theme.FontSize.headline, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        ZStack {
            // 拖拽背景
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .fill(isDragOver ? Color.blue.opacity(0.15) : Color.fillSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .stroke(isDragOver ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .frame(height: 200)
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    handleDrop(providers: providers)
                }

            // 内容
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else if isVideo, let url = selectedURL {
                VideoThumbnailView(url: url)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else {
                emptyState
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDragOver)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isDragOver ? "arrow.down.doc.fill" : "photo.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(isDragOver ? .blue : .textQuaternary)
                .scaleEffect(isDragOver ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isDragOver)

            Text(isDragOver ? L10n.wallpaperAdd : L10n.wallpaperSelectHint)
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(isDragOver ? .blue : .textSecondary)

            Text(L10n.wallpaperSelectHint)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textQuaternary)

            Button(L10n.wallpaperSelect) { openFilePicker() }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(.blue.opacity(0.15)))
                .buttonStyle(.plain)
        }
    }

    // MARK: - File Info

    private var fileInfoBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 文件类型图标
            Image(systemName: isVideo ? "film" : "photo")
                .font(.system(size: 14))
                .foregroundColor(isVideo ? .purple : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(fileSize)
                    if !imageDimensions.isEmpty {
                        Text("·")
                        Text(imageDimensions)
                    }
                }
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textQuaternary)
            }

            Spacer()

            // 清除选择
            Button {
                clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textQuaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(L10n.restore) {
                openFilePicker()
            }
            .font(.system(size: Theme.FontSize.body, weight: .medium))
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().stroke(Color.fillStrong, lineWidth: 1))
            .buttonStyle(.plain)

            if selectedURL != nil {
                Button(L10n.wallpaperAdd) {
                    addWallpaper()
                }
                .font(.system(size: Theme.FontSize.body, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white))
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Format Hint

    private var formatHint: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.system(size: 9))
            Text(L10n.wallpaperFormats)
        }
        .font(.system(size: Theme.FontSize.caption2))
        .foregroundColor(.textQuaternary)
    }

    // MARK: - Actions

    private func openFilePicker() {
        // 临时降低灵动岛窗口层级，避免遮挡文件选择器
        IslandWindowManager.shared.temporarilyLowerLevel()
        IslandStore.isPanelPresented = true

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .image, .jpeg, .png,
            .init(filenameExtension: "webp") ?? .data,
            .mpeg4Movie, .quickTimeMovie,
        ]

        let result = panel.runModal()

        // 恢复灵动岛窗口层级
        IslandStore.isPanelPresented = false
        IslandWindowManager.shared.restoreLevel()

        guard result == .OK, let url = panel.url else { return }
        processSelectedFile(url)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                processSelectedFile(url)
            }
        }
        return true
    }

    private func processSelectedFile(_ url: URL) {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let ext = url.pathExtension.lowercased()
        let validImageExts = ["jpg", "jpeg", "png", "webp"]
        let validVideoExts = ["mp4", "mov", "m4v"]

        guard validImageExts.contains(ext) || validVideoExts.contains(ext) else {
            errorMessage = L10n.error
            showError = true
            return
        }

        // 检查文件大小（限制 100MB）
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int, size > 100 * 1024 * 1024 {
            errorMessage = L10n.error
            showError = true
            return
        }

        selectedURL = url
        isVideo = validVideoExts.contains(ext)
        fileName = url.lastPathComponent
        fileSize = formatFileSize(url)

        if !isVideo {
            if let image = NSImage(contentsOf: url) {
                previewImage = image
                imageDimensions = "\(Int(image.size.width)) × \(Int(image.size.height))"
            }
        } else {
            imageDimensions = ""
            previewImage = nil
        }
    }

    private func clearSelection() {
        selectedURL = nil
        previewImage = nil
        isVideo = false
        fileName = ""
        fileSize = ""
        imageDimensions = ""
    }

    private func addWallpaper() {
        guard let url = selectedURL else { return }
        store.addWallpaper(from: url)
        dismiss()
    }

    private func formatFileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024) }
        return String(format: "%.1f MB", Double(size) / 1024 / 1024)
    }
}
