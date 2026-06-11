//
//  EventListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Event List View

/// 倒数日列表视图
struct EventListView: View {
    @ObservedObject var store: EventStore

    @State private var showAddSheet = false

    var body: some View {
        Group {
            if store.sortedItems.isEmpty {
                onboardingView
            } else {
                eventListView
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEventSheet(store: store, isPresented: $showAddSheet)
                .onAppear { NotificationCenter.default.post(name: .sheetPresented, object: nil) }
                .onDisappear { NotificationCenter.default.post(name: .sheetDismissed, object: nil) }
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text(L10n.eventTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(L10n.eventTrack)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showAddSheet = true
            } label: {
                Label(L10n.add, systemImage: "plus")
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.fillSubtle))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - Main List

    private var eventListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("\(store.items.count) \(L10n.count)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(.textTertiary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(store.sortedItems) { item in
                        eventCard(item)
                    }
                }
            }
        }
    }

    // MARK: - Event Card

    private func eventCard(_ item: EventItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // 背景图片或纯色
            if let path = item.backgroundImagePath, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                            .fill(
                                LinearGradient(
                                    colors: [.black.opacity(0.7), .black.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .fill(eventTypeColor(item.eventType).opacity(0.12))
                    .frame(height: 90)
            }

            // 内容
            HStack(spacing: Theme.Spacing.md) {
                // 天数
                VStack(spacing: 2) {
                    Text("\(abs(item.daysRemaining))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(item.isPast ? .white.opacity(0.5) : .white)
                    Text(item.isPast ? L10n.eventDaysPassed : L10n.days)
                        .font(.system(size: Theme.FontSize.caption2))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 55)

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(item.eventType.rawValue)
                            .font(.system(size: Theme.FontSize.caption2, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.2)))

                        Text(item.targetDate, style: .date)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // 操作按钮
                VStack(spacing: 8) {
                    // 更换照片
                    Button {
                        pickImageForEvent(item)
                    } label: {
                        Image(systemName: "photo")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    // 删除
                    Button { store.deleteEvent(id: item.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .frame(height: 90)
    }

    // MARK: - Image Picker (更换封面)

    private func pickImageForEvent(_ item: EventItem) {
        guard let url = IslandWindowManager.openFilePanel(configure: {
            $0.title = "选择封面图片"
            $0.allowedContentTypes = [.image, .jpeg, .png]
            $0.allowsMultipleSelection = false
            $0.canChooseDirectories = false
            if let picturesDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first,
               FileManager.default.fileExists(atPath: picturesDir.path) {
                $0.directoryURL = picturesDir
            } else {
                $0.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            }
        }) else { return }
        handleImageForEvent(url: url, item: item)
    }

    private func handleImageForEvent(url: URL, item: EventItem) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let eventsDir = appSupport.appendingPathComponent("EventImages")
        try? FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)

        let fileName = "\(item.id.uuidString).jpg"
        let destURL = eventsDir.appendingPathComponent(fileName)

        guard let sourceImage = NSImage(contentsOf: url) else { return }
        guard let cropped = cropToSquare(sourceImage) else { return }

        if let tiffData = cropped.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: destURL)
            store.updateBackgroundImage(id: item.id, path: destURL.path)
        }
    }

    /// 裁剪为正方形（取中心区域）
    private func cropToSquare(_ image: NSImage) -> NSImage? {
        let size = image.size
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        let cropRect = NSRect(x: x, y: y, width: side, height: side)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedCG, size: NSSize(width: side, height: side))
    }

    // MARK: - Helpers

    private func eventTypeColor(_ type: EventType) -> Color {
        switch type {
        case .countdown: return .blue
        case .anniversary: return .pink
        case .birthday: return .purple
        case .holiday: return .green
        case .exam: return .orange
        }
    }
}

// MARK: - Add Event Sheet

/// 添加倒数日 Sheet（显示在灵动岛上）
struct AddEventSheet: View {
    @ObservedObject var store: EventStore
    @Binding var isPresented: Bool

    @State private var title = ""
    @State private var type: EventType = .countdown
    @State private var date = Date()
    @State private var imagePath: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 标题栏
            HStack {
                Text("新建倒数日")
                    .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textTertiary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)
            }

            // 照片 + 表单
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                // 照片选择
                photoPickerButton

                // 表单
                VStack(spacing: Theme.Spacing.sm) {
                    TextField("输入标题", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(.textPrimary)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

                    HStack(spacing: Theme.Spacing.sm) {
                        Picker("类型", selection: $type) {
                            ForEach(EventType.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.menu)

                        DatePicker("日期", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            // 按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button("添加") {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addEvent(title: trimmed, type: type, targetDate: date, backgroundImagePath: imagePath)
                    isPresented = false
                }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor))
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 360)
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
    }

    // MARK: - Photo Picker

    private var photoPickerButton: some View {
        Button {
            pickImage()
        } label: {
            if let path = imagePath, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                    Text("选择封面")
                        .font(.system(size: 9))
                }
                .foregroundColor(.textTertiary)
                .frame(width: 80, height: 80)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func pickImage() {
        guard let url = IslandWindowManager.openFilePanel(configure: {
            $0.title = "选择封面图片"
            $0.allowedContentTypes = [.image, .jpeg, .png]
            $0.allowsMultipleSelection = false
            $0.canChooseDirectories = false
            if let picturesDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first,
               FileManager.default.fileExists(atPath: picturesDir.path) {
                $0.directoryURL = picturesDir
            } else {
                $0.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            }
        }) else { return }
        handleImageSelection(url: url, id: UUID().uuidString)
    }

    private func handleImageSelection(url: URL, id: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let eventsDir = appSupport.appendingPathComponent("EventImages")
        try? FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)

        let fileName = "\(id).jpg"
        let destURL = eventsDir.appendingPathComponent(fileName)

        guard let sourceImage = NSImage(contentsOf: url) else { return }
        guard let cropped = cropToSquare(sourceImage) else { return }

        if let tiffData = cropped.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: destURL)
            imagePath = destURL.path
        }
    }

    private func cropToSquare(_ image: NSImage) -> NSImage? {
        let size = image.size
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        let cropRect = NSRect(x: x, y: y, width: side, height: side)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedCG, size: NSSize(width: side, height: side))
    }
}
