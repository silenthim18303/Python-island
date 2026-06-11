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

    @State private var showAddEvent = false
    @State private var newTitle = ""
    @State private var newType: EventType = .countdown
    @State private var newDate = Date()
    @State private var newImagePath: String?

    var body: some View {
        if store.sortedItems.isEmpty && !showAddEvent {
            onboardingView
        } else {
            eventListView
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
                showAddEvent = true
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
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if showAddEvent {
                addEventForm
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

    // MARK: - Add Event Form

    private var addEventForm: some View {
        VStack(spacing: Theme.Spacing.md) {
            // 照片选择
            photoPickerButton(imagePath: $newImagePath)

            // 标题输入
            TextField(L10n.eventName, text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textPrimary)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

            // 类型 + 日期
            HStack(spacing: Theme.Spacing.sm) {
                Picker(L10n.eventTitle, selection: $newType) {
                    ForEach(EventType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)

                DatePicker(L10n.eventDate, selection: $newDate, displayedComponents: .date)
                    .labelsHidden()
            }

            // 按钮
            HStack {
                Button(L10n.cancel) {
                    showAddEvent = false
                    newTitle = ""
                    newImagePath = nil
                }
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .buttonStyle(.plain)

                Spacer()

                Button(L10n.add) {
                    let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    store.addEvent(title: title, type: newType, targetDate: newDate, backgroundImagePath: newImagePath)
                    showAddEvent = false
                    newTitle = ""
                    newImagePath = nil
                }
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fillSubtle))
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Photo Picker

    private func photoPickerButton(imagePath: Binding<String?>) -> some View {
        Button {
            pickImage(path: imagePath)
        } label: {
            if let path = imagePath.wrappedValue, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                    Text("封面")
                        .font(.system(size: 9))
                }
                .foregroundColor(.textTertiary)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
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

    // MARK: - Image Picker

    private func pickImage(path: Binding<String?>) {
        let panel = NSOpenPanel()
        panel.title = "选择封面图片"
        panel.allowedContentTypes = [.image, .jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // 复制到应用目录并裁剪为正方形
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let eventsDir = appSupport.appendingPathComponent("EventImages")
        try? FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).jpg"
        let destURL = eventsDir.appendingPathComponent(fileName)

        guard let sourceImage = NSImage(contentsOf: url) else { return }
        guard let cropped = cropToSquare(sourceImage) else { return }

        // 压缩保存
        if let tiffData = cropped.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: destURL)
            path.wrappedValue = destURL.path
        }
    }

    private func pickImageForEvent(_ item: EventItem) {
        let panel = NSOpenPanel()
        panel.title = "选择封面图片"
        panel.allowedContentTypes = [.image, .jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

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

    private func daysColor(_ days: Int) -> Color {
        if days <= 1 { return .red }
        if days <= 7 { return .orange }
        if days <= 30 { return .yellow }
        return .green
    }

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
