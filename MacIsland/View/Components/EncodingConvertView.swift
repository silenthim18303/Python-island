//
//  EncodingConvertView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Encoding Convert View

/// 文本编码转换视图
struct EncodingConvertView: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var sourceEncoding: TextEncoding = .utf8
    @State private var targetEncoding: TextEncoding = .utf16
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 输入
            TextEditor(text: $inputText)
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .foregroundColor(.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            // 编码选择
            HStack(spacing: Theme.Spacing.sm) {
                encodingPicker(L10n.encodingFrom, selection: $sourceEncoding)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                encodingPicker(L10n.encodingTo, selection: $targetEncoding)

                Spacer()

                Button { convert() } label: {
                    Text(L10n.encodingConvert)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: Theme.FontSize.caption2))
                    .foregroundColor(.red.opacity(0.7))
            }

            // 输出
            if !outputText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L10n.encodingResult)
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(outputText, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(outputText)
                        .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .textSelection(.enabled)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
                }
            }
        }
    }

    // MARK: - Encoding Picker

    private func encodingPicker(_ label: String, selection: Binding<TextEncoding>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textTertiary)
            Picker("", selection: selection) {
                ForEach(TextEncoding.allCases) { enc in
                    Text(enc.displayName).tag(enc)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
    }

    // MARK: - Convert

    private func convert() {
        errorMessage = nil
        guard let inputData = inputText.data(using: sourceEncoding.encoding) else {
            errorMessage = "无法用 \(sourceEncoding.displayName) 编码输入文本"
            return
        }
        guard let result = String(data: inputData, encoding: targetEncoding.encoding) else {
            errorMessage = "转换失败"
            return
        }
        outputText = result
    }
}

// MARK: - TextEncoding

private enum TextEncoding: String, CaseIterable, Identifiable {
    case utf8, utf16, utf16BE, utf16LE, ascii, isoLatin1, windowsCP1252

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16BE: return "UTF-16 BE"
        case .utf16LE: return "UTF-16 LE"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO Latin-1"
        case .windowsCP1252: return "Windows CP1252"
        }
    }

    var encoding: String.Encoding {
        switch self {
        case .utf8: return .utf8
        case .utf16: return .utf16
        case .utf16BE: return .utf16BigEndian
        case .utf16LE: return .utf16LittleEndian
        case .ascii: return .ascii
        case .isoLatin1: return .isoLatin1
        case .windowsCP1252: return .windowsCP1252
        }
    }
}
