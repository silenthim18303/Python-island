//
//  WallpaperView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - Wallpaper View

/// 壁纸管理主界面
struct WallpaperView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var github = GitHubService.shared
    @State private var selectedSection: Section = .local
    @State private var uploadTarget: WallpaperItem?
    @State private var showUploadConfirm = false
    @State private var isUploading = false
    @State private var uploadResult: String?
    @State private var selectedLocalWallpaper: WallpaperItem?

    enum Section: String, CaseIterable {
        case local = "local"
        case community = "community"
    }

    private var uploadUsername: String {
        UserDefaults.standard.string(forKey: "communityUploadUsername") ?? ""
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 当前壁纸预览
            if store.activeWallpaper != nil {
                activeWallpaperSection
            }

            // 分段选择
            Picker("", selection: $selectedSection) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.sm)

            // 内容
            switch selectedSection {
            case .local: localSection
            case .community: WallpaperCommunityView(store: store)
            }
        }
        .alert(L10n.wallpaperUpload, isPresented: $showUploadConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.wallpaperUpload) {
                if let target = uploadTarget {
                    performUpload(target)
                }
            }
        } message: {
            if let target = uploadTarget {
                Text("\(L10n.wallpaperUploadConfirm)\n\(L10n.settingsUsername): \(uploadUsername)")
            }
        }
        .sheet(item: $selectedLocalWallpaper) { wallpaper in
            LocalWallpaperDetailSheet(wallpaper: wallpaper, store: store)
        }
    }

    // MARK: - Active Wallpaper

    private var activeWallpaperSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text(L10n.wallpaperCurrent)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Button("关闭壁纸") {
                    store.clearActiveWallpaper()
                }
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.red.opacity(0.7))
                .buttonStyle(.plain)
            }

            if let wallpaper = store.activeWallpaper {
                HStack(spacing: Theme.Spacing.sm) {
                    wallpaperThumbnail(wallpaper: wallpaper, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wallpaper.name)
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(.textPrimary)
                        Text(wallpaper.isVideo ? L10n.wallpaperVideo : L10n.wallpaperStatic)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                    }
                    Spacer()
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        .padding(.horizontal, Theme.Spacing.sm)
    }

    // MARK: - Local Section

    private var localSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 添加按钮
            HStack {
                Text(L10n.wallpaperLocal)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Button {
                    openFilePicker()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.sm)

            // 壁纸网格
            if store.wallpapers.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                ], spacing: Theme.Spacing.xs) {
                    ForEach(store.wallpapers) { wallpaper in
                        wallpaperGridItem(wallpaper)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
    }

    // MARK: - Grid Item

    private func wallpaperGridItem(_ wallpaper: WallpaperItem) -> some View {
        Button {
            selectedLocalWallpaper = wallpaper
        } label: {
            VStack(spacing: 4) {
                wallpaperThumbnail(wallpaper: wallpaper, size: 60)

                Text(wallpaper.name)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                if store.activeWallpaper?.id == wallpaper.id {
                    Text(L10n.wallpaperInUse)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(store.activeWallpaper?.id == wallpaper.id ? Color.green : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Thumbnail

    private func wallpaperThumbnail(wallpaper: WallpaperItem, size: CGFloat) -> some View {
        Group {
            if wallpaper.isVideo {
                // 视频壁纸显示第一帧
                if let url = wallpaper.fileURL {
                    VideoThumbnailView(url: url)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    placeholderIcon(size: size)
                }
            } else if let url = wallpaper.fileURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                placeholderIcon(size: size)
            }
        }
    }

    private func placeholderIcon(size: CGFloat) -> some View {
        Image(systemName: "photo")
            .font(.system(size: size * 0.3))
            .foregroundColor(.textQuaternary)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))
    }

    // MARK: - Upload

    private func performUpload(_ wallpaper: WallpaperItem) {
        guard let url = wallpaper.fileURL else { return }
        isUploading = true
        uploadResult = nil

        Task {
            let result = await store.uploadCommunityWallpaper(from: url, username: uploadUsername)
            isUploading = false

            switch result {
            case .success(let prURL):
                uploadResult = "\(L10n.wallpaperUploadSuccess): \(prURL)"
            case .failure(let error):
                uploadResult = "\(L10n.wallpaperUploadFail): \(error)"
            }
        }
    }

    // MARK: - Empty State

    private func openFilePicker() {
        IslandWindowManager.shared.temporarilyLowerLevel()

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
        IslandWindowManager.shared.restoreLevel()

        guard result == .OK, let url = panel.url else { return }
        store.addWallpaper(from: url)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.1))
            Text(L10n.wallpaperAdd)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Video Thumbnail View

/// 视频缩略图 — 使用 AVAssetImageGenerator 获取第一帧
struct VideoThumbnailView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.cornerRadius = 4
        layer.masksToBounds = true
        nsView.layer = layer
        return nsView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Local Wallpaper Detail Sheet

/// 本地壁纸详情弹窗 — 预览图 + 信息 + 操作按钮
struct LocalWallpaperDetailSheet: View {
    let wallpaper: WallpaperItem
    @ObservedObject var store: WallpaperStore
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showUploadConfirm = false
    @State private var isUploading = false
    @State private var uploadResult: String?
    @ObservedObject private var github = GitHubService.shared

    private var isActive: Bool { store.activeWallpaper?.id == wallpaper.id }
    private var uploadUsername: String { UserDefaults.standard.string(forKey: "communityUploadUsername") ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(L10n.wallpaperDetail)
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)

            // 预览图
            Group {
                if let url = wallpaper.fileURL {
                    if wallpaper.isVideo {
                        VideoThumbnailView(url: url)
                            .frame(height: 180)
                    } else if let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 180)
                    } else {
                        placeholderImage
                    }
                } else {
                    placeholderImage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            // 信息区
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(wallpaper.name)
                    .font(.system(size: Theme.FontSize.headline, weight: .bold))
                    .foregroundColor(.textPrimary)

                HStack(spacing: Theme.Spacing.sm) {
                    infoChip(icon: wallpaper.isVideo ? "film" : "photo", text: wallpaper.isVideo ? L10n.wallpaperVideo : L10n.wallpaperImage)
                    if let ext = wallpaper.fileURL?.pathExtension.uppercased() {
                        infoChip(icon: "doc", text: ext)
                    }
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: wallpaper.localPath),
                       let size = attrs[.size] as? Int64 {
                        infoChip(icon: "doc.badge.gearshape", text: formatFileSize(size))
                    }
                    if wallpaper.source == .community {
                        infoChip(icon: "globe", text: L10n.wallpaperCommunity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider().background(.white.opacity(0.1))

            // 操作按钮
            VStack(spacing: Theme.Spacing.sm) {
                // 设为壁纸 / 使用中
                if isActive {
                    Label(L10n.wallpaperInUse, systemImage: "checkmark.circle.fill")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.green.opacity(0.15)))
                } else {
                    Button {
                        store.setActive(wallpaper)
                        dismiss()
                    } label: {
                        Label(L10n.wallpaperSelect, systemImage: "photo.fill")
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.appAccent))
                    }
                    .buttonStyle(.plain)
                }

                // 管理操作
                HStack(spacing: Theme.Spacing.sm) {
                    // 上传到社区
                    Button {
                        showUploadConfirm = true
                    } label: {
                        Label(L10n.wallpaperUpload, systemImage: "arrow.up.circle")
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!github.isAuthenticated || uploadUsername.isEmpty)

                    // 删除
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(.red.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if let result = uploadResult {
                    Text(result)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(result.contains(L10n.wallpaperUploadFail) ? .red : .green)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            NotificationCenter.default.post(name: .sheetPresented, object: nil)
        }
        .onDisappear {
            NotificationCenter.default.post(name: .sheetDismissed, object: nil)
        }
        .alert(L10n.confirm, isPresented: $showDeleteConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                store.deleteWallpaper(wallpaper)
                dismiss()
            }
        } message: {
            Text("\(L10n.delete)「\(wallpaper.name)」？")
        }
        .alert(L10n.wallpaperUpload, isPresented: $showUploadConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.wallpaperUpload) {
                isUploading = true
                Task {
                    if let url = wallpaper.fileURL {
                        let result = await store.uploadCommunityWallpaper(from: url, username: uploadUsername)
                        isUploading = false
                        switch result {
                        case .success(let prURL): uploadResult = "\(L10n.wallpaperUploadSuccess): \(prURL)"
                        case .failure(let error): uploadResult = "\(L10n.wallpaperUploadFail): \(error)"
                        }
                    }
                }
            }
        } message: {
            Text(L10n.wallpaperUploadConfirm)
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes)B" }
        if bytes < 1024 * 1024 { return String(format: "%.0fK", Double(bytes) / 1024) }
        return String(format: "%.1fM", Double(bytes) / 1024 / 1024)
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.md)
            .fill(Color.fillSubtle)
            .frame(height: 180)
            .overlay(Image(systemName: "photo").font(.system(size: 32)).foregroundColor(.textQuaternary))
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text)
        }
        .font(.system(size: Theme.FontSize.caption2, weight: .medium))
        .foregroundColor(.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.fillSubtle))
    }
}
