import SwiftUI

/// 章節目錄：右側滑入半透明側欄，支援搜尋、卷群組、千章快速捲動、自動定位當前章節
struct ChapterListSheet: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onChapterSelected: (Int) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Filtered Items

    private var filteredItems: [(offset: Int, chapter: Chapter)] {
        let all = chapters.enumerated().map { (offset: $0.offset, chapter: $0.element) }
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.chapter.title.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Volume Grouping

    /// 偵測章節標題中的「卷」模式，將連續章節歸入同一卷群組
    private var volumeGroups: [VolumeSection] {
        guard searchText.isEmpty else { return [] }

        var groups: [VolumeSection] = []
        var currentVolume: String? = nil
        var currentItems: [(offset: Int, chapter: Chapter)] = []
        var groupIndex = 0

        for (offset, chapter) in chapters.enumerated() {
            let title = chapter.title
            if Self.isVolumeHeader(title) {
                // 將之前積累的章節歸入前一卷
                if !currentItems.isEmpty {
                    groups.append(VolumeSection(
                        id: groupIndex,
                        volumeTitle: currentVolume,
                        items: currentItems
                    ))
                    groupIndex += 1
                    currentItems = []
                }
                currentVolume = title
            }
            currentItems.append((offset: offset, chapter: chapter))
        }

        // 最後一組
        if !currentItems.isEmpty {
            groups.append(VolumeSection(
                id: groupIndex,
                volumeTitle: currentVolume,
                items: currentItems
            ))
        }

        // 若只有一組且無卷標題，回傳空（使用平面列表）
        if groups.count <= 1 && groups.first?.volumeTitle == nil {
            return []
        }
        return groups
    }

    /// 偵測標題是否為「卷」標頭（如「卷一 起始」、「第一卷 序章」）
    private static let volumePatterns: [Regex<Substring>] = [
        try! Regex(#"^卷[零一二三四五六七八九十百千萬\d]+"#),
        try! Regex(#"^第[零一二三四五六七八九十百千萬\d]+[卷部]"#),
    ]

    private static func isVolumeHeader(_ title: String) -> Bool {
        for pattern in volumePatterns {
            if title.firstMatch(of: pattern) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            searchBar
            chapterCountBar

            if filteredItems.isEmpty {
                emptyState
            } else {
                chapterList
                    .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(
            ZStack {
                NNColor.appBackground.opacity(0.88)
                    .ignoresSafeArea()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: -8, y: 0)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(alignment: .center) {
            Text("目錄")
                .font(NNFont.uiTitle)
                .foregroundStyle(NNColor.textPrimary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(NNColor.textTertiary)
                    .frame(minWidth: NNSpacing.minTouchTarget, minHeight: NNSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("關閉目錄")
        }
        .padding(.horizontal, NNSpacing.lg)
        .padding(.top, NNSpacing.lg)
        .padding(.bottom, NNSpacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: NNSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(NNColor.textTertiary)

            TextField("搜尋章節", text: $searchText)
                .font(NNFont.uiBody)
                .foregroundStyle(NNColor.textPrimary)
                .tint(NNColor.accent)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(NNColor.textTertiary)
                        .frame(minWidth: NNSpacing.minTouchTarget, minHeight: NNSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("清除搜尋")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(NNColor.cardBackground)
        )
        .padding(.horizontal, NNSpacing.lg)
        .padding(.bottom, NNSpacing.sm)
    }

    // MARK: - Chapter Count

    private var chapterCountBar: some View {
        VStack(spacing: 0) {
            HStack {
                Text(searchText.isEmpty
                     ? "共 \(chapters.count) 章"
                     : "找到 \(filteredItems.count) 章")
                    .font(NNFont.uiCaption)
                    .foregroundStyle(NNColor.textTertiary)

                Spacer()

                if searchText.isEmpty && currentChapterIndex < chapters.count {
                    Text("目前第 \(currentChapterIndex + 1) 章")
                        .font(NNFont.uiCaption)
                        .foregroundStyle(NNColor.accent)
                }
            }
            .padding(.horizontal, NNSpacing.lg)
            .padding(.vertical, NNSpacing.xs)

            Rectangle()
                .fill(NNColor.separator)
                .frame(height: 0.5)
        }
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let groups = volumeGroups
                if groups.isEmpty {
                    // 平面列表（無卷分組或搜尋中）
                    flatChapterList
                } else {
                    // 卷分組列表
                    groupedChapterList(groups)
                }
            }
            .scrollIndicators(.visible)
            .onAppear {
                guard searchText.isEmpty else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    if reduceMotion {
                        proxy.scrollTo(currentChapterIndex, anchor: .center)
                    } else {
                        withAnimation(NNAnimation.progressUpdate) {
                            proxy.scrollTo(currentChapterIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Flat List

    private var flatChapterList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredItems, id: \.offset) { item in
                chapterRow(offset: item.offset, chapter: item.chapter)

                if item.offset != filteredItems.last?.offset {
                    Rectangle()
                        .fill(NNColor.separator)
                        .frame(height: 0.5)
                        .padding(.leading, NNSpacing.lg + 36 + NNSpacing.sm)
                }
            }
        }
        .padding(.vertical, NNSpacing.xs)
    }

    // MARK: - Grouped List

    private func groupedChapterList(_ groups: [VolumeSection]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(groups) { group in
                // 卷標題
                if let volumeTitle = group.volumeTitle {
                    volumeHeader(title: volumeTitle)
                }

                // 該卷下的章節
                ForEach(group.items, id: \.offset) { item in
                    chapterRow(offset: item.offset, chapter: item.chapter)

                    if item.offset != group.items.last?.offset {
                        Rectangle()
                            .fill(NNColor.separator)
                            .frame(height: 0.5)
                            .padding(.leading, NNSpacing.lg + 36 + NNSpacing.sm)
                    }
                }
            }
        }
        .padding(.vertical, NNSpacing.xs)
    }

    // MARK: - Volume Header

    private func volumeHeader(title: String) -> some View {
        HStack(spacing: NNSpacing.sm) {
            Rectangle()
                .fill(NNColor.accent)
                .frame(width: 3, height: 16)
                .clipShape(Capsule())

            Text(title)
                .font(NNFont.uiSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(NNColor.accentLight)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, NNSpacing.lg)
        .padding(.top, NNSpacing.lg)
        .padding(.bottom, NNSpacing.xs)
    }

    // MARK: - Chapter Row

    @ViewBuilder
    private func chapterRow(offset: Int, chapter: Chapter) -> some View {
        let isCurrent = offset == currentChapterIndex
        let isRead = offset < currentChapterIndex

        Button {
            onChapterSelected(offset)
        } label: {
            HStack(spacing: NNSpacing.sm) {
                // 章節序號
                Text("\(offset + 1)")
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(
                        isCurrent ? NNColor.accent :
                        isRead ? NNColor.textTertiary : NNColor.textSecondary
                    )
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)

                // 章節標題
                Text(chapter.title)
                    .font(NNFont.uiBody)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(
                        isCurrent ? NNColor.accentLight :
                        isRead ? NNColor.textSecondary : NNColor.textPrimary
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)

                // 狀態指示
                if isCurrent {
                    Image(systemName: "book.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(NNColor.accent)
                } else if isRead {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(NNColor.textTertiary)
                }
            }
            .padding(.horizontal, NNSpacing.lg)
            .padding(.vertical, 12)
            .background(
                isCurrent
                    ? NNColor.accent.opacity(0.1)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(offset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: NNSpacing.sm) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(NNColor.textTertiary)
            Text("找不到「\(searchText)」")
                .font(NNFont.uiBody)
                .foregroundStyle(NNColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Volume Section Model

private struct VolumeSection: Identifiable {
    let id: Int
    let volumeTitle: String?
    let items: [(offset: Int, chapter: Chapter)]
}
