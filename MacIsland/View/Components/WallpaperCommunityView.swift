//
//  WallpaperCommunityView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Wallpaper Community View

/// 社区壁纸浏览与上传
struct WallpaperCommunityView: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var github = GitHubService.shared
    @State private var showUploadPicker = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var uploadSuccess: String?
    @State private var showGitHubConfig = false
    @State private var filter: Filter = .all
    @State private var deleteTarget: CommunityWallpaper?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var selectedWallpaper: CommunityWallpaper?

    enum Filter: String, CaseIterable {
        case all = "all"
        case mine = "mine"
    }

    private var uploadUsername: String {
        UserDefaults.standard.string(forKey: "communityUploadUsername") ?? ""
    }

    /// 筛选后的壁纸列表
    private var filteredWallpapers: [CommunityWallpaper] {
        switch filter {
        case .all:
            // 全部 tab 隐藏私有壁纸
            return store.communityWallpapers.filter { !store.isWallpaperPrivate($0) }
        case .mine:
            return store.communityWallpapers.filter { $0.author == uploadUsername }
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 标题栏
            HStack {
                Text(L10n.wallpaperCommunity)
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()

                // 上传按钮（始终显示，未登录时弹出配置）
                if github.isAuthorizing {
                    if let code = github.userCode {
                        VStack(spacing: 4) {
                            Text(code)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.appAccent)
                            Text(L10n.wallpaperGitHubLogin)
                                .font(.system(size: 9))
                                .foregroundColor(.textQuaternary)
                        }
                    }
                } else {
                    Button {
                        if github.isAuthenticated {
                            showUploadPicker = true
                        } else {
                            showGitHubConfig = true
                        }
                    } label: {
                        Image(systemName: github.isAuthenticated ? "arrow.up.circle.fill" : "person.crop.circle.badge.plus")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(github.isAuthenticated && (uploadUsername.isEmpty || isUploading))
                }

                // 刷新按钮
                Button {
                    Task { await store.fetchCommunityWallpapers() }
                } label: {
                    if store.isLoadingCommunity {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.isLoadingCommunity)
            }
            .padding(.horizontal, Theme.Spacing.sm)

            // 筛选器
            if !store.communityWallpapers.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { filter = f }
                        } label: {
                            Text(f.rawValue)
                                .font(.system(size: 10, weight: filter == f ? .semibold : .medium))
                                .foregroundColor(filter == f ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    filter == f
                                        ? Capsule().fill(.white.opacity(0.15))
                                        : nil
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if filter == .mine {
                        Text("\(filteredWallpapers.count) \(L10n.count)")
                            .font(.system(size: 9))
                            .foregroundColor(.textQuaternary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }

            // 上传状态
            if isUploading {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(L10n.wallpaperUploading)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.textTertiary)
                }
            }

            if let error = uploadError {
                Text(error)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, Theme.Spacing.sm)
            }

            if let success = uploadSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(success)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }

            // 错误提示
            if let error = store.communityError {
                Text(error)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.horizontal, Theme.Spacing.sm)
            }

            // 壁纸网格
            if filteredWallpapers.isEmpty && !store.isLoadingCommunity {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                    GridItem(.flexible(), spacing: Theme.Spacing.xs),
                ], spacing: Theme.Spacing.xs) {
                    ForEach(filteredWallpapers) { wallpaper in
                        communityGridItem(wallpaper)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
        }
        .onAppear {
            Task { await store.fetchCommunityWallpapers() }
        }
        .fileImporter(
            isPresented: $showUploadPicker,
            allowedContentTypes: [.image, .jpeg, .png, .mpeg4Movie, .quickTimeMovie],
            allowsMultipleSelection: false
        ) { result in
            IslandStore.isPanelPresented = false
            handleUpload(result)
        }
        .onChange(of: showUploadPicker) { _, showing in
            IslandStore.isPanelPresented = showing
        }
        .sheet(isPresented: $showGitHubConfig) {
            gitHubConfigSheet
        }
        .alert(L10n.confirm, isPresented: $showDeleteConfirm) {
            Button(L10n.cancel, role: .cancel) { }
            Button(L10n.delete, role: .destructive) {
                if let target = deleteTarget {
                    performDelete(target)
                }
            }
        } message: {
            if let target = deleteTarget {
                Text(L10n.wallpaperPRConfirm)
            }
        }
        .sheet(item: $selectedWallpaper) { wallpaper in
            WallpaperDetailSheet(
                wallpaper: wallpaper,
                store: store,
                isDownloaded: store.wallpapers.contains { $0.name == wallpaper.name && $0.author == wallpaper.author }
            )
        }
    }

    // MARK: - Upload

    private func handleUpload(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard !uploadUsername.isEmpty else {
            uploadError = L10n.wallpaperUsernameRequired
            return
        }

        isUploading = true
        uploadError = nil
        uploadSuccess = nil

        Task {
            let uploadResult = await store.uploadCommunityWallpaper(
                from: url,
                username: uploadUsername
            )
            isUploading = false

            switch uploadResult {
            case .success(let prURL):
                uploadSuccess = "已提交审核，PR: \(prURL)"
            case .failure(let error):
                uploadError = error
            }
        }
    }

    // MARK: - Delete

    private func performDelete(_ community: CommunityWallpaper) {
        print("[Wallpaper] 开始删除: \(community.name) by \(community.author)")
        isDeleting = true
        uploadError = nil
        uploadSuccess = nil

        Task {
            let result = await store.deleteCommunityWallpaper(community)
            isDeleting = false

            switch result {
            case .success(let prURL):
                print("[Wallpaper] 删除成功: \(prURL)")
                uploadSuccess = "已提交删除审核，PR: \(prURL)"
            case .failure(let error):
                print("[Wallpaper] 删除失败: \(error)")
                uploadError = error
            }
        }
    }

    // MARK: - Grid Item

    private func communityGridItem(_ wallpaper: CommunityWallpaper) -> some View {
        Button {
            selectedWallpaper = wallpaper
        } label: {
            VStack(spacing: 4) {
                AsyncImage(url: URL(string: wallpaper.thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    case .failure:
                        placeholderIcon
                    case .empty:
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 60, height: 60)
                    @unknown default:
                        placeholderIcon
                    }
                }

                Text(wallpaper.name)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    Text(wallpaper.author)
                        .font(.system(size: 8))
                        .foregroundColor(.textQuaternary)
                    if wallpaper.isVideo {
                        Image(systemName: "film")
                            .font(.system(size: 7))
                            .foregroundColor(.textQuaternary)
                    }
                }

                if wallpaper.isDownloaded {
                    Text(L10n.wallpaperDownloaded)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.green)
                }

                if store.isWallpaperPrivate(wallpaper) {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 6))
                        Text(L10n.wallpaperPrivate)
                    }
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.orange)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(wallpaper.isDownloaded ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if wallpaper.author == uploadUsername {
                Button {
                    store.toggleWallpaperPrivacy(wallpaper)
                } label: {
                    Label(
                        store.isWallpaperPrivate(wallpaper) ? "取消私有" : L10n.wallpaperSetPrivate,
                        systemImage: store.isWallpaperPrivate(wallpaper) ? "eye" : "eye.slash"
                    )
                }

                Divider()

                Button(role: .destructive) {
                    deleteTarget = wallpaper
                    showDeleteConfirm = true
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Helpers

    private var placeholderIcon: some View {
        Image(systemName: "photo")
            .font(.system(size: 18))
            .foregroundColor(.textQuaternary)
            .frame(width: 60, height: 60)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.fillSubtle))
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if store.isLoadingCommunity {
                ProgressView(L10n.wallpaperLoading)
                    .controlSize(.small)
                    .foregroundColor(.textSecondary)
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.1))
                Text(L10n.wallpaperRefresh)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textQuaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - GitHub Config Sheet

    @ViewBuilder
    private var gitHubConfigSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.wallpaperCommunityUpload)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button { showGitHubConfig = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // 用户名
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.wallpaperGitHubUser)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSecondary)
                TextField("用于壁纸目录命名", text: Binding(
                    get: { UserDefaults.standard.string(forKey: "communityUploadUsername") ?? "" },
                    set: { UserDefaults.standard.set($0, forKey: "communityUploadUsername") }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.fillSubtle))
            }

            // 登录按钮
            Button {
                showGitHubConfig = false
                Task { await github.startDeviceFlow() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text(L10n.wallpaperGitHub)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.appAccent))
            }
            .buttonStyle(.plain)
            .disabled(
                UserDefaults.standard.string(forKey: "communityUploadUsername")?.isEmpty ?? true
            )
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Wallpaper Detail Sheet

/// 社区壁纸详情弹窗 — 预览图 + 信息 + 操作按钮 + 管理功能
struct WallpaperDetailSheet: View {
    let wallpaper: CommunityWallpaper
    @ObservedObject var store: WallpaperStore
    @ObservedObject private var settings = AppSettings.shared
    let isDownloaded: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var isDownloading = false
    @State private var showDeleteConfirm = false
    @State private var isUploading = false
    @State private var uploadResult: String?

    private var uploadUsername: String {
        UserDefaults.standard.string(forKey: "communityUploadUsername") ?? ""
    }

    private var isActive: Bool {
        store.activeWallpaper?.name == wallpaper.name && store.activeWallpaper?.author == wallpaper.author
    }

    private var isOwn: Bool {
        wallpaper.author == uploadUsername
    }

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
            AsyncImage(url: URL(string: wallpaper.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                case .failure:
                    imagePlaceholder
                case .empty:
                    ProgressView()
                        .frame(height: 180)
                @unknown default:
                    imagePlaceholder
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            // 信息区
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(wallpaper.name)
                    .font(.system(size: Theme.FontSize.headline, weight: .bold))
                    .foregroundColor(.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.textQuaternary)
                    Text(wallpaper.author)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    infoChip(icon: wallpaper.isVideo ? "film" : "photo", text: wallpaper.isVideo ? L10n.wallpaperVideo : L10n.wallpaperImage)
                    infoChip(icon: "doc", text: fileExtension.uppercased())
                    if store.isWallpaperPrivate(wallpaper) {
                        infoChip(icon: "lock.fill", text: L10n.wallpaperPrivate)
                    }
                    if isDownloaded {
                        infoChip(icon: "checkmark.circle", text: L10n.wallpaperDownloaded)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider().background(.white.opacity(0.1))

            // 操作按钮
            VStack(spacing: Theme.Spacing.sm) {
                // 主操作：下载 / 设为壁纸 / 使用中
                if isDownloaded {
                    if isActive {
                        Label(L10n.wallpaperInUse, systemImage: "checkmark.circle.fill")
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.green.opacity(0.15)))
                    } else {
                        Button {
                            if let localItem = store.wallpapers.first(where: { $0.name == wallpaper.name && $0.author == wallpaper.author }) {
                                store.setActive(localItem)
                                dismiss()
                            }
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
                } else {
                    Button {
                        isDownloading = true
                        Task {
                            await store.downloadCommunityWallpaper(wallpaper)
                            isDownloading = false
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isDownloading { ProgressView().controlSize(.mini) }
                            else { Image(systemName: "arrow.down.circle.fill") }
                            Text(isDownloading ? "下载中…" : L10n.wallpaperDownload)
                        }
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(isDownloading ? .gray : Color.appAccent))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloading)
                }

                // 管理操作（自己的壁纸）
                if isOwn {
                    HStack(spacing: Theme.Spacing.sm) {
                        // 私有切换
                        Button {
                            store.toggleWallpaperPrivacy(wallpaper)
                        } label: {
                            Label(
                                store.isWallpaperPrivate(wallpaper) ? "取消私有" : L10n.wallpaperSetPrivate,
                                systemImage: store.isWallpaperPrivate(wallpaper) ? "eye" : "eye.slash"
                            )
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

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
                }

                // 上传结果提示
                if let result = uploadResult {
                    Text(result)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(result.contains("失败") ? .red : .green)
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
                Task {
                    let result = await store.deleteCommunityWallpaper(wallpaper)
                    if case .success = result {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("\(L10n.delete)「\(wallpaper.name)」？")
        }
    }

    private var fileExtension: String {
        if wallpaper.isVideo { return "mp4" }
        let ext = (wallpaper.imageURL as NSString).pathExtension
        return ext.isEmpty ? "jpg" : ext
    }

    private var imagePlaceholder: some View {
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
