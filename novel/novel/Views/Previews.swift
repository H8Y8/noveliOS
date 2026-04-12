import SwiftUI
import SwiftData

// MARK: - Preview Helpers

/// Preview 專用的 SwiftData 容器（記憶體內，不影響真實資料）
@MainActor
private let previewContainer: ModelContainer = {
    let schema = Schema([Book.self, Chapter.self, UserSettings.self, Bookmark.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)

    // 插入範例書籍
    let sampleContent = """
    第一章 起始

    這是一個測試用的段落，用來展示閱讀器的排版效果。

    清晨的陽光灑在窗台上，微風輕輕吹動著窗簾。

    第二章 轉折

    故事開始有了變化，角色之間的關係也漸漸改變。

    他走在街道上，思考著接下來該怎麼做。

    第三章 結局

    一切都有了答案，故事也終於畫上句點。
    """

    let book = Book(title: "範例小說", fileName: "sample.txt", content: sampleContent)
    let chapters = ChapterParser.parseChapters(from: sampleContent)
    book.chapters = chapters
    for chapter in chapters { chapter.book = book }
    book.readingProgress = 0.35
    container.mainContext.insert(book)

    // 插入第二本書（展示多書庫狀態）
    let book2 = Book(title: "第二本書", fileName: "book2.txt", content: "測試內容")
    book2.readingProgress = 0.72
    container.mainContext.insert(book2)

    // 插入設定
    container.mainContext.insert(UserSettings())

    return container
}()

/// 取得 Preview 用的範例書籍
@MainActor
private var previewBook: Book {
    let descriptor = FetchDescriptor<Book>(
        sortBy: [SortDescriptor(\.dateLastRead, order: .reverse)]
    )
    return (try? previewContainer.mainContext.fetch(descriptor).first) ?? Book(title: "Preview", fileName: "p.txt", content: "")
}

/// Preview 用的 TTSService
@MainActor
private let previewTTSService = TTSService()

// MARK: - LibraryView Previews

#Preview("書庫 — 有書") {
    LibraryView()
        .environment(previewTTSService)
        .modelContainer(previewContainer)
}

#Preview("書庫 — 空書架") {
    LibraryView()
        .environment(previewTTSService)
        .modelContainer({
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(
                for: Book.self, Chapter.self, UserSettings.self, Bookmark.self,
                configurations: config
            )
        }())
}

// MARK: - BookCardView Previews

#Preview("書卡 — 靜止") {
    HStack(spacing: NNSpacing.cardSpacing) {
        BookCardView(
            book: previewBook,
            isPlaying: false,
            appearIndex: 0
        )
        BookCardView(
            book: previewBook,
            isPlaying: true,
            appearIndex: 1
        )
    }
    .padding(NNSpacing.md)
    .background(NNColor.appBackground)
    .modelContainer(previewContainer)
}

// MARK: - ReaderView Preview

#Preview("閱讀器") {
    NavigationStack {
        ReaderView(book: previewBook)
    }
    .environment(previewTTSService)
    .modelContainer(previewContainer)
}

// MARK: - ScrollReaderView Preview

#Preview("捲動閱讀") {
    let paragraphs = [
        "清晨的陽光灑在窗台上，微風輕輕吹動著窗簾。",
        "他走在街道上，思考著接下來該怎麼做。",
        "一切都有了答案，故事也終於畫上句點。",
        "這是第四段，用來測試段落間距和排版效果。",
        "最後一段測試文字，確認底部安全距離是否正確。",
    ]

    ScrollReaderView(
        paragraphs: paragraphs,
        theme: .dark,
        fontSize: 18,
        lineSpacing: 1.5,
        fontFamily: "System",
        highlightedParagraphIndex: 1,
        bookmarkedIndices: [0, 3],
        visibleParagraphIndex: .constant(0),
        scrollCommand: .constant(nil)
    )
    .background(ReadingTheme.dark.backgroundColor)
}

// MARK: - SettingsSheet Preview

#Preview("設定面板") {
    Text("")
        .sheet(isPresented: .constant(true)) {
            SettingsSheet(
                bookId: UUID(),
                allParagraphs: ["段落一", "段落二", "段落三"],
                synthesisService: BookSynthesisService()
            )
            .environment(previewTTSService)
            .modelContainer(previewContainer)
        }
}

// MARK: - NarratorPlayerView Preview

#Preview("說書人面板") {
    Text("")
        .sheet(isPresented: .constant(true)) {
            NarratorPlayerView(
                book: previewBook,
                chapterTitle: "第一章 起始",
                allParagraphs: ["段落一", "段落二", "段落三"],
                synthesisService: BookSynthesisService()
            )
            .environment(previewTTSService)
            .modelContainer(previewContainer)
        }
}

// MARK: - ChapterListSheet Preview

#Preview("章節目錄") {
    let chapters = (0..<20).map { i in
        Chapter(
            index: i,
            title: "第\(i + 1)章 測試章節標題",
            startOffset: i * 1000,
            endOffset: (i + 1) * 1000
        )
    }

    ZStack(alignment: .trailing) {
        NNColor.appBackground.ignoresSafeArea()
        ChapterListSheet(
            chapters: chapters,
            currentChapterIndex: 5,
            onChapterSelected: { _ in },
            onDismiss: {}
        )
        .frame(width: 320)
    }
}

// MARK: - OnboardingView Preview

#Preview("引導頁") {
    OnboardingView(onFinish: {})
}

// MARK: - ReadingTheme Previews

#Preview("主題色彩") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(ReadingTheme.allCases) { theme in
                VStack(alignment: .leading, spacing: NNSpacing.sm) {
                    Text(theme.displayName)
                        .font(NNFont.uiHeadline)
                        .foregroundStyle(theme.textColor)
                    Text(theme.displayDescription)
                        .font(NNFont.uiBody)
                        .foregroundStyle(theme.secondaryTextColor)
                    Text("高亮段落預覽")
                        .font(NNFont.uiBody)
                        .foregroundStyle(theme.textColor)
                        .padding(NNSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(theme.highlightColor)
                        )
                }
                .padding(NNSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundColor)
            }
        }
    }
}
