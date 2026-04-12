import SwiftUI

/// 全文搜尋面板：搜尋書本內容，點擊結果跳轉至對應段落
struct SearchSheet: View {
    let paragraphs: [String]
    let onResultSelected: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [(index: Int, preview: String)] = []

    var body: some View {
        ZStack {
            NNColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜尋列
                HStack(spacing: NNSpacing.sm) {
                    HStack(spacing: NNSpacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(NNColor.textTertiary)

                        TextField("搜尋內容", text: $searchText)
                            .font(NNFont.uiBody)
                            .foregroundStyle(NNColor.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { performSearch() }
                            .onChange(of: searchText) { _, newValue in
                                if newValue.isEmpty { results = [] }
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                results = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(NNColor.textTertiary)
                            }
                            .accessibilityLabel("清除搜尋")
                        }
                    }
                    .padding(.horizontal, NNSpacing.sm)
                    .frame(height: 36)
                    .background(NNColor.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("搜尋") { performSearch() }
                        .font(NNFont.uiBody)
                        .foregroundStyle(NNColor.accent)
                }
                .padding(.horizontal, NNSpacing.lg)
                .padding(.vertical, NNSpacing.sm)

                // 結果數量
                if !searchText.isEmpty {
                    HStack {
                        Text(results.isEmpty
                             ? String(localized: "沒有找到結果")
                             : String(localized: "找到 \(results.count) 個結果"))
                            .font(NNFont.uiCaption)
                            .foregroundStyle(NNColor.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, NNSpacing.lg)
                    .padding(.bottom, NNSpacing.xs)
                }

                // 搜尋結果列表
                if results.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(NNColor.appBackground)
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(spacing: NNSpacing.md) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(NNColor.textTertiary)
            Text("輸入關鍵字搜尋書本內容")
                .font(NNFont.uiBody)
                .foregroundStyle(NNColor.textSecondary)
            Spacer()
        }
    }

    private var resultsList: some View {
        List(results, id: \.index) { result in
            Button {
                dismiss()
                onResultSelected(result.index)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    highlightedText(result.preview, keyword: searchText)
                        .font(NNFont.uiBody)
                        .lineLimit(3)

                    Text("第 \(result.index + 1) 段")
                        .font(NNFont.uiCaption2)
                        .foregroundStyle(NNColor.textTertiary)
                }
                .padding(.vertical, NNSpacing.xs)
            }
            .listRowBackground(NNColor.cardBackground)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Search Logic

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            return
        }

        results = paragraphs.enumerated().compactMap { index, text in
            guard text.localizedCaseInsensitiveContains(query) else { return nil }
            return (index: index, preview: String(text.prefix(120)))
        }
    }

    /// 將搜尋關鍵字在文字中以強調色標示
    private func highlightedText(_ text: String, keyword: String) -> Text {
        guard !keyword.isEmpty else {
            return Text(text).foregroundColor(NNColor.textPrimary)
        }

        let lowText = text.lowercased()
        let lowKey = keyword.lowercased()
        var result = Text("")
        var remaining = text
        var lowRemaining = lowText

        while let range = lowRemaining.range(of: lowKey) {
            let before = remaining[remaining.startIndex..<range.lowerBound]
            let match = remaining[range]

            result = result + Text(before).foregroundColor(NNColor.textPrimary)
            result = result + Text(match).foregroundColor(NNColor.accent).bold()

            remaining = String(remaining[range.upperBound...])
            lowRemaining = String(lowRemaining[range.upperBound...])
        }

        result = result + Text(remaining).foregroundColor(NNColor.textPrimary)
        return result
    }
}
