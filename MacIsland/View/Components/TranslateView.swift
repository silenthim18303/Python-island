//
//  TranslateView.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/3.
//

import SwiftUI

// MARK: - Translate View

/// 简易翻译工具视图（使用 macOS 内置翻译或手动查词）
struct TranslateView: View {
    @State private var inputText = ""
    @State private var translatedText = ""
    @State private var sourceLang: TranslateLang = .auto
    @State private var targetLang: TranslateLang = .zh
    @State private var isTranslating = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // 语言选择
            HStack(spacing: Theme.Spacing.sm) {
                langPicker("从", selection: $sourceLang)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
                langPicker("到", selection: $targetLang)
                Spacer()
            }

            // 输入
            TextEditor(text: $inputText)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))

            HStack {
                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button { translate() } label: {
                    Text("翻译")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.fillSubtle))
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || isTranslating)
            }

            // 输出
            if !translatedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("翻译结果")
                            .font(.system(size: Theme.FontSize.caption2))
                            .foregroundColor(.textQuaternary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(translatedText, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(translatedText)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(.textSecondary)
                        .textSelection(.enabled)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Color.fillSubtle))
                }
            }
        }
    }

    // MARK: - Language Picker

    private func langPicker(_ label: String, selection: Binding<TranslateLang>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: Theme.FontSize.caption2))
                .foregroundColor(.textTertiary)
            Picker("", selection: selection) {
                ForEach(TranslateLang.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
    }

    // MARK: - Translate

    private func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isTranslating = true

        // 使用 macOS 原生 NSSpellChecker 的自动翻译建议
        // 或简单地通过 URL 编码调用免费翻译 API
        Task {
            let result = await callTranslationAPI(text: text, from: sourceLang, to: targetLang)
            await MainActor.run {
                translatedText = result
                isTranslating = false
            }
        }
    }

    private func callTranslationAPI(text: String, from source: TranslateLang, to target: TranslateLang) async -> String {
        // 使用 LibreTranslate 免费 API（无需密钥）
        let sourceCode = source == .auto ? "auto" : source.code
        let targetCode = target.code

        guard let url = URL(string: "https://libretranslate.com/translate") else { return "" }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "q": text,
            "source": sourceCode,
            "target": targetCode,
            "format": "text"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let translatedText = json["translatedText"] as? String {
                return translatedText
            }
        } catch {
            return "翻译请求失败: \(error.localizedDescription)"
        }

        return "翻译服务暂时不可用"
    }
}

// MARK: - TranslateLang

private enum TranslateLang: String, CaseIterable, Identifiable {
    case auto, zh, en, ja, ko, fr, de, es, ru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .zh: return "中文"
        case .en: return "英文"
        case .ja: return "日文"
        case .ko: return "韩文"
        case .fr: return "法文"
        case .de: return "德文"
        case .es: return "西文"
        case .ru: return "俄文"
        }
    }

    var code: String { rawValue }
}
