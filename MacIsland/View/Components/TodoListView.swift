//
//  TodoListView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Todo List View

/// 完整待办事项列表视图
struct TodoListView: View {
    @ObservedObject var store: TodoStore

    @State private var inputText = ""
    @State private var selectedPriority: Priority = .p2
    @State private var expandedTodoId: UUID?
    @State private var descriptionText = ""
    @State private var subInputTexts: [UUID: String] = [:]
    @State private var subInputPriorities: [UUID: Priority] = [:]
    @State private var showTrash = false
    @FocusState private var isInputFocused: Bool
    @FocusState private var focusedSubInput: UUID?

    var body: some View {
        if store.activeItems.isEmpty && store.deletedItems.isEmpty {
            onboardingView
        } else {
            todoListView
        }
    }

    // MARK: - Empty State

    private var onboardingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.15))
                .padding(.top, 20)

            Text(L10n.todoTitle)
                .font(.system(size: Theme.FontSize.headline, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(L10n.todoEmpty)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.md) {
                featureBadge(icon: "arrow.up.circle.fill", text: "P0 \(L10n.todoHigh)", color: .red)
                featureBadge(icon: "exclamationmark.circle.fill", text: "P1 \(L10n.todoMedium)", color: .orange)
                featureBadge(icon: "info.circle.fill", text: "P2 \(L10n.todoLow)", color: .blue)
            }

            todoInput
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.lg)
    }

    private func featureBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: Theme.FontSize.caption2))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Main List

    private var todoListView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            statsBar
            todoInput
            todoItemsList
            trashSection
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            statChip(text: "\(L10n.todoComplete) \(store.doneCount)", color: .green)
            statChip(text: "\(L10n.todoPending) \(store.undoneCount)", color: .white.opacity(0.6))

            Spacer()

            if store.p0Count > 0 {
                statChip(text: "P0 \(store.p0Count)", color: .red)
            }
            if store.p1Count > 0 {
                statChip(text: "P1 \(store.p1Count)", color: .orange)
            }
            if store.p2Count > 0 {
                statChip(text: "P2 \(store.p2Count)", color: .blue)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private func statChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.caption2, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Input

    private var todoInput: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 优先级选择
            Menu {
                ForEach(Priority.allCases) { p in
                    Button { selectedPriority = p } label: {
                        HStack {
                            Text(p.label)
                            if selectedPriority == p {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(selectedPriority.label)
                    .font(.system(size: Theme.FontSize.caption, weight: .bold))
                    .foregroundColor(priorityColor(selectedPriority))
                    .frame(width: 28)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(priorityColor(selectedPriority).opacity(0.15)))
            }
            .menuStyle(.borderlessButton)

            TextField(L10n.todoPlaceholder, text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textPrimary)
                .focused($isInputFocused)
                .onSubmit { addTodo() }

            Button { addTodo() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(inputText.isEmpty ? .textQuaternary : .white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Todo Items List

    private var todoItemsList: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(store.activeItems) { item in
                todoItemRow(item)
            }
        }
    }

    private func todoItemRow(_ item: TodoItem) -> some View {
        let isExpanded = expandedTodoId == item.id

        return VStack(spacing: 0) {
            // 主行
            HStack(spacing: Theme.Spacing.sm) {
                // 勾选框
                Button { store.toggleTodo(id: item.id) } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(item.done ? .green : .textTertiary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.text)
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(item.done ? .textQuaternary : .textPrimary)
                        .strikethrough(item.done)
                        .lineLimit(1)

                    if !item.subItems.isEmpty {
                        let completed = item.subItems.filter(\.done).count
                        Text("\(completed)/\(item.subItems.count) \(L10n.todoSubtask)")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                    }
                }

                Spacer()

                // 优先级标签
                if item.priority != .p2 || item.done == false {
                    Text(item.priority.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(priorityColor(item.priority))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(priorityColor(item.priority).opacity(0.15)))
                }

                // 展开/折叠
                if item.description != "" || !item.subItems.isEmpty {
                    Button { toggleExpand(item.id) } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // 删除
                Button { store.deleteTodo(id: item.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.textQuaternary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .background(Circle().fill(.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .contentShape(Rectangle())
            .onTapGesture { toggleExpand(item.id) }

            // 展开区域
            if isExpanded {
                expandedContent(item)
                    .padding(.leading, 26)
                    .padding(.top, Theme.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 分隔线
            if item.id != store.activeItems.last?.id {
                Divider()
                    .background(Color.hairline)
                    .padding(.leading, 26)
            }
        }
    }

    // MARK: - Expanded Content

    private func expandedContent(_ item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 描述编辑
            descriptionEditor(item)

            // 子任务列表
            if !item.subItems.isEmpty {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(item.subItems) { sub in
                        subItemRow(parentId: item.id, sub: sub)
                    }
                }
            }

            // 子任务输入
            subTaskInput(parentId: item.id)
        }
    }

    private func descriptionEditor(_ item: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.todoDescription)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textQuaternary)

            TextEditor(text: Binding(
                get: { item.description },
                set: { store.updateDescription(id: item.id, description: $0) }
            ))
            .font(.system(size: Theme.FontSize.caption))
            .foregroundColor(.textSecondary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 40, maxHeight: 80)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
        }
    }

    private func subItemRow(parentId: UUID, sub: TodoItem) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button { store.toggleSubItem(parentId: parentId, subId: sub.id) } label: {
                Image(systemName: sub.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(sub.done ? .green : .textTertiary)
            }
            .buttonStyle(.plain)

            Text(sub.text)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(sub.done ? .textQuaternary : .textSecondary)
                .strikethrough(sub.done)

            Spacer()

            Text(sub.priority.label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(priorityColor(sub.priority))

            Button { store.deleteSubItem(parentId: parentId, subId: sub.id) } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.textQuaternary)
            }
            .buttonStyle(.plain)
        }
    }

    private func subTaskInput(parentId: UUID) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Menu {
                ForEach(Priority.allCases) { p in
                    Button {
                        subInputPriorities[parentId] = p
                    } label: {
                        Text(p.label)
                    }
                }
            } label: {
                Text((subInputPriorities[parentId] ?? .p2).label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(priorityColor(subInputPriorities[parentId] ?? .p2))
                    .frame(width: 20)
            }
            .menuStyle(.borderlessButton)

            TextField("\(L10n.add)\(L10n.todoSubtask)...", text: Binding(
                get: { subInputTexts[parentId] ?? "" },
                set: { subInputTexts[parentId] = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: Theme.FontSize.caption))
            .foregroundColor(.textSecondary)
            .focused($focusedSubInput, equals: parentId)
            .onSubmit { addSubTask(parentId: parentId) }

            Button { addSubTask(parentId: parentId) } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundColor((subInputTexts[parentId] ?? "").isEmpty ? .textQuaternary : .textSecondary)
            }
            .buttonStyle(.plain)
            .disabled((subInputTexts[parentId] ?? "").isEmpty)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Trash Section

    private var trashSection: some View {
        VStack(spacing: 0) {
            if !store.deletedItems.isEmpty {
                // 折叠/展开按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showTrash.toggle() }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                        Text("\(L10n.todoTrash) (\(store.deletedItems.count))")
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        Spacer()
                        if showTrash {
                            Button(L10n.clear, role: .destructive) {
                                store.emptyTrash()
                            }
                            .font(.system(size: Theme.FontSize.caption2))
                            .buttonStyle(.plain)
                            .foregroundColor(.red.opacity(0.8))
                        }
                        Image(systemName: showTrash ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.textTertiary)
                    .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.plain)

                // 已删除项列表
                if showTrash {
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(store.deletedItems) { item in
                            deletedItemRow(item)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func deletedItemRow(_ item: TodoItem) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(item.text)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(.textQuaternary)
                .strikethrough(true)
                .lineLimit(1)

            Spacer()

            // 恢复
            Button { store.restoreTodo(id: item.id) } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help(L10n.restore)

            // 永久删除
            Button { store.permanentDelete(id: item.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(L10n.delete)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
    }

    // MARK: - Helpers

    private func addTodo() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addTodo(text: text, priority: selectedPriority)
        inputText = ""
        selectedPriority = .p2
    }

    private func addSubTask(parentId: UUID) {
        let text = (subInputTexts[parentId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let priority = subInputPriorities[parentId] ?? .p2
        store.addSubItem(parentId: parentId, text: text, priority: priority)
        subInputTexts[parentId] = ""
        subInputPriorities[parentId] = .p2
    }

    private func toggleExpand(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedTodoId = expandedTodoId == id ? nil : id
        }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .p0: return .red
        case .p1: return .orange
        case .p2: return .blue
        }
    }
}
