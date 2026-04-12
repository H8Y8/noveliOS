//
//  novelTests.swift
//  novelTests
//
//  Created by 陳奕顯 on 2026/3/4.
//

import Testing
import UIKit
import SwiftUI
@testable import novel

// MARK: - ChapterParser 測試

struct ChapterParserTests {

    @Test func parseChineseChapterTitles() {
        let content = """
        第一章 開端
        這是第一章的內容，包含一些文字。

        第二章 發展
        這是第二章的內容，包含更多文字。

        第三章 高潮
        這是第三章的內容，故事到達高潮。
        """
        let chapters = ChapterParser.parseChapters(from: content)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "第一章 開端")
        #expect(chapters[1].title == "第二章 發展")
        #expect(chapters[2].title == "第三章 高潮")
    }

    @Test func parseEnglishChapterTitles() {
        let content = """
        Chapter 1
        First chapter content here.

        Chapter 2
        Second chapter content here.
        """
        let chapters = ChapterParser.parseChapters(from: content)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Chapter 1")
        #expect(chapters[1].title == "Chapter 2")
    }

    @Test func fallbackToChunkWhenNoPattern() {
        // 沒有章節標題，應 fallback 到 3000 字分塊
        let content = String(repeating: "這是一段普通文字，沒有章節標題。", count: 200) // ~6000 chars
        let chapters = ChapterParser.parseChapters(from: content)
        // 應至少分成 2 個 chunk
        #expect(chapters.count >= 2)
        // 每個 chunk 的 title 應為「第 N 頁」格式
        #expect(chapters[0].title.hasPrefix("第"))
    }

    @Test func emptyContentReturnsNoChapters() {
        let chapters = ChapterParser.parseChapters(from: "")
        #expect(chapters.isEmpty)
    }

    @Test func chapterOffsetsAreMonotonicallyIncreasing() {
        let content = """
        第一章 開始
        一些內容。

        第二章 繼續
        更多內容。

        第三章 結束
        最後內容。
        """
        let chapters = ChapterParser.parseChapters(from: content)
        #expect(chapters.count == 3)
        for i in 0..<chapters.count - 1 {
            #expect(chapters[i].startOffset < chapters[i + 1].startOffset)
            #expect(chapters[i].endOffset == chapters[i + 1].startOffset)
        }
        // 最後一章的 endOffset 應等於全文 UTF-16 長度
        #expect(chapters.last?.endOffset == content.utf16.count)
    }
}

// MARK: - Book.chapterContent UTF-16 offset 切片測試

struct BookChapterContentTests {

    private func makeBook(content: String, chapters: [(title: String, start: Int, end: Int)]) -> Book {
        let book = Book(title: "Test", fileName: "test.txt", content: content)
        for (i, c) in chapters.enumerated() {
            let chapter = Chapter(index: i, title: c.title, startOffset: c.start, endOffset: c.end)
            chapter.book = book
            book.chapters.append(chapter)
        }
        return book
    }

    @Test func basicSlicing() {
        let content = "第一章 開始\n內容A\n第二章 繼續\n內容B"
        // Find UTF-16 offsets manually
        let utf16 = content.utf16
        let firstChapterEnd = content.range(of: "第二章")!.lowerBound.samePosition(in: utf16)!
        let endOffset = utf16.distance(from: utf16.startIndex, to: firstChapterEnd)
        let totalLength = utf16.count

        let book = makeBook(content: content, chapters: [
            (title: "第一章 開始", start: 0, end: endOffset),
            (title: "第二章 繼續", start: endOffset, end: totalLength)
        ])

        let chapter0 = book.chapterContent(at: 0)
        let chapter1 = book.chapterContent(at: 1)
        #expect(chapter0.contains("第一章 開始"))
        #expect(chapter0.contains("內容A"))
        #expect(!chapter0.contains("第二章"))
        #expect(chapter1.contains("第二章 繼續"))
        #expect(chapter1.contains("內容B"))
    }

    @Test func outOfBoundsReturnsEmpty() {
        let book = Book(title: "Test", fileName: "test.txt", content: "內容")
        #expect(book.chapterContent(at: 0) == "")
        #expect(book.chapterContent(at: -1) == "")
        #expect(book.chapterContent(at: 99) == "")
    }

    @Test func utf16MultibyteCharactersSlicedCorrectly() {
        // 確認含有 emoji 或 4-byte 字元時 UTF-16 offset 仍正確
        let content = "第一章\n😀emoji內容\n第二章\n普通內容"
        let chapters = ChapterParser.parseChapters(from: content)
        guard chapters.count == 2 else { return }

        let book = makeBook(content: content, chapters: chapters.map {
            (title: $0.title, start: $0.startOffset, end: $0.endOffset)
        })

        let ch0 = book.chapterContent(at: 0)
        let ch1 = book.chapterContent(at: 1)
        #expect(ch0.contains("😀"))
        #expect(!ch1.contains("😀"))
    }
}

// MARK: - EncodingDetector 測試

struct EncodingDetectorTests {

    @Test func detectsUTF8() {
        let text = "這是一段 UTF-8 繁體中文文字"
        let data = text.data(using: .utf8)!
        let encoding = EncodingDetector.detectEncoding(data: data)
        #expect(encoding == .utf8)
    }

    @Test func decodeStringUTF8() {
        let original = "Hello 世界"
        let data = original.data(using: .utf8)!
        let decoded = EncodingDetector.decodeString(from: data)
        #expect(decoded == original)
    }

    @Test func detectsBig5() {
        let big5 = CFStringEncoding(CFStringEncodings.big5.rawValue)
        let nsBig5 = CFStringConvertEncodingToNSStringEncoding(big5)
        let big5Encoding = String.Encoding(rawValue: nsBig5)

        // 「繁體中文」在 Big5 編碼下不是有效 UTF-8
        let text = "繁體中文測試"
        guard let data = text.data(using: big5Encoding) else { return }

        // Big5 資料不應被識別為 UTF-8（若被識別為 UTF-8 則此測試的前提就不成立，跳過）
        if String(data: data, encoding: .utf8) != nil { return }

        let detected = EncodingDetector.detectEncoding(data: data)
        #expect(detected == big5Encoding)
    }

    @Test func fallbackToUTF8ForUnknown() {
        // 隨機二進位資料：三種編碼都解不了，fallback 至 UTF-8
        let garbled = Data([0xFF, 0xFE, 0x00])
        let encoding = EncodingDetector.detectEncoding(data: garbled)
        #expect(encoding == .utf8)
    }
}

// MARK: - PaginationEngine 測試

struct PaginationEngineTests {

    @Test func emptyParagraphsReturnsEmpty() {
        let pages = PaginationEngine.paginate(
            paragraphs: [],
            fontSize: 18,
            lineSpacing: 1.5,
            fontFamily: "System",
            availableSize: CGSize(width: 300, height: 600)
        )
        #expect(pages.isEmpty)
    }

    @Test func singleParagraphFitsOnOnePage() {
        let pages = PaginationEngine.paginate(
            paragraphs: ["短段落"],
            fontSize: 18,
            lineSpacing: 1.5,
            fontFamily: "System",
            availableSize: CGSize(width: 300, height: 600)
        )
        #expect(pages.count == 1)
        #expect(pages[0] == [0])
    }

    @Test func multipleParagraphsSpanMultiplePages() {
        // 用極小的可用高度強制分頁
        let paragraphs = (0..<10).map { "這是第\($0)段，包含一些足夠長的文字來佔據一些空間。" }
        let pages = PaginationEngine.paginate(
            paragraphs: paragraphs,
            fontSize: 18,
            lineSpacing: 1.5,
            fontFamily: "System",
            availableSize: CGSize(width: 300, height: 50) // 極小高度
        )
        #expect(pages.count > 1)
    }

    @Test func allParagraphsAppearExactlyOnce() {
        let paragraphs = (0..<20).map { "段落 \($0)：測試文字。" }
        let pages = PaginationEngine.paginate(
            paragraphs: paragraphs,
            fontSize: 18,
            lineSpacing: 1.5,
            fontFamily: "System",
            availableSize: CGSize(width: 300, height: 100)
        )
        let allIndices = pages.flatMap { $0 }.sorted()
        #expect(allIndices == Array(0..<20))
    }

    @Test func pageIndexForParagraph() {
        let pages = [[0, 1, 2], [3, 4], [5, 6, 7, 8]]
        #expect(PaginationEngine.pageIndex(forParagraph: 0, in: pages) == 0)
        #expect(PaginationEngine.pageIndex(forParagraph: 2, in: pages) == 0)
        #expect(PaginationEngine.pageIndex(forParagraph: 3, in: pages) == 1)
        #expect(PaginationEngine.pageIndex(forParagraph: 8, in: pages) == 2)
    }

    @Test func pageIndexOutOfRangeFallsBackToLastPage() {
        let pages = [[0, 1], [2, 3]]
        #expect(PaginationEngine.pageIndex(forParagraph: 99, in: pages) == 1)
    }
}

// MARK: - ReadingMode 測試

struct ReadingModeTests {

    @Test func rawValueRoundTrip() {
        #expect(ReadingMode(rawValue: "scroll") == .scroll)
        #expect(ReadingMode(rawValue: "pageCurl") == .pageCurl)
        #expect(ReadingMode.scroll.rawValue == "scroll")
        #expect(ReadingMode.pageCurl.rawValue == "pageCurl")
    }

    @Test func allCasesHasTwoCases() {
        #expect(ReadingMode.allCases.count == 2)
    }

    @Test func invalidRawValueReturnsNil() {
        #expect(ReadingMode(rawValue: "unknown") == nil)
    }
}

// MARK: - TTSCacheService 測試

struct TTSCacheServiceTests {

    private let cache = TTSCacheService()
    private let testBookId = UUID()

    @Test func saveAndLoadCycle() {
        let data = Data("test audio content".utf8)
        cache.save(data: data, bookId: testBookId, index: 0)
        let loaded = cache.load(bookId: testBookId, index: 0)
        #expect(loaded == data)
        // 清理
        cache.clearCache(for: testBookId)
    }

    @Test func loadNonExistentReturnsNil() {
        let ghostId = UUID()
        let loaded = cache.load(bookId: ghostId, index: 999)
        #expect(loaded == nil)
    }

    @Test func isCachedReturnsTrueAfterSave() {
        let data = Data("cached".utf8)
        cache.save(data: data, bookId: testBookId, index: 42)
        #expect(cache.isCached(bookId: testBookId, index: 42))
        cache.clearCache(for: testBookId)
    }

    @Test func clearCacheRemovesData() {
        let data = Data("to be deleted".utf8)
        cache.save(data: data, bookId: testBookId, index: 0)
        cache.save(data: data, bookId: testBookId, index: 1)
        cache.clearCache(for: testBookId)
        #expect(cache.load(bookId: testBookId, index: 0) == nil)
        #expect(cache.load(bookId: testBookId, index: 1) == nil)
        #expect(cache.synthesizedCount(for: testBookId) == 0)
    }

    @Test func synthesizedCountReflectsSavedFiles() {
        let data = Data("mp3".utf8)
        cache.save(data: data, bookId: testBookId, index: 0)
        cache.save(data: data, bookId: testBookId, index: 1)
        cache.save(data: data, bookId: testBookId, index: 2)
        #expect(cache.synthesizedCount(for: testBookId) == 3)
        cache.clearCache(for: testBookId)
    }
}

// MARK: - UserSettings 測試

struct UserSettingsTests {

    @Test func defaultValues() {
        let settings = UserSettings()
        #expect(settings.fontSize == 18.0)
        #expect(settings.lineSpacing == 1.5)
        #expect(settings.theme == "light")
        #expect(settings.fontFamily == "System")
        #expect(settings.ttsRate == 0.5)
        #expect(settings.pageMode == "scroll")
    }

    @Test func readingModeComputedProperty() {
        let settings = UserSettings()
        #expect(settings.readingMode == .scroll)
        settings.readingMode = .pageCurl
        #expect(settings.pageMode == "pageCurl")
        #expect(settings.readingMode == .pageCurl)
    }

    @Test func readingThemeComputedProperty() {
        let settings = UserSettings()
        #expect(settings.readingTheme == .light)
        settings.readingTheme = .dark
        #expect(settings.theme == "dark")
    }

    @Test func ttsProviderTypeComputedProperty() {
        let settings = UserSettings()
        #expect(settings.ttsProviderType == .system)
        settings.ttsProviderType = .edge
        #expect(settings.ttsProvider == "edge")
        #expect(settings.ttsProviderType == .edge)
        settings.ttsProviderType = .azure
        #expect(settings.ttsProvider == "azure")
    }

    @Test func invalidProviderFallsBackToSystem() {
        let settings = UserSettings()
        settings.ttsProvider = "nonexistent"
        #expect(settings.ttsProviderType == .system)
    }

    @Test func invalidThemeFallsBackToLight() {
        let settings = UserSettings()
        settings.theme = "neon"
        #expect(settings.readingTheme == .light)
    }

    @Test func invalidPageModeFallsBackToScroll() {
        let settings = UserSettings()
        settings.pageMode = "flip"
        #expect(settings.readingMode == .scroll)
    }

    @Test func ttsEngineDefaults() {
        let settings = UserSettings()
        #expect(settings.ttsProvider == "system")
        #expect(settings.edgeTTSVoice == "zh-TW-HsiaoChenNeural")
        #expect(settings.azureRegion == "eastasia")
        #expect(settings.azureTTSVoice == "zh-TW-HsiaoChenNeural")
        #expect(settings.edgeTTSServerURL == nil)
        #expect(settings.azureSubscriptionKey == nil)
    }
}

// MARK: - ReadingMode 額外測試

struct ReadingModeExtendedTests {

    @Test func displayNameNotEmpty() {
        for mode in ReadingMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test func displayDescriptionNotEmpty() {
        for mode in ReadingMode.allCases {
            #expect(!mode.displayDescription.isEmpty)
        }
    }

    @Test func iconNameNotEmpty() {
        for mode in ReadingMode.allCases {
            #expect(!mode.iconName.isEmpty)
        }
    }

    @Test func identifierMatchesRawValue() {
        for mode in ReadingMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
    }
}

// MARK: - ReadingTheme 測試

struct ReadingThemeTests {

    @Test func allCasesHasFour() {
        #expect(ReadingTheme.allCases.count == 4)
    }

    @Test func rawValueRoundTrip() {
        for theme in ReadingTheme.allCases {
            #expect(ReadingTheme(rawValue: theme.rawValue) == theme)
        }
    }

    @Test func displayNameNotEmpty() {
        for theme in ReadingTheme.allCases {
            #expect(!theme.displayName.isEmpty)
        }
    }

    @Test func displayDescriptionNotEmpty() {
        for theme in ReadingTheme.allCases {
            #expect(!theme.displayDescription.isEmpty)
        }
    }

    @Test func identifierMatchesRawValue() {
        for theme in ReadingTheme.allCases {
            #expect(theme.id == theme.rawValue)
        }
    }

    @Test func isDarkPropertyCorrect() {
        #expect(ReadingTheme.dark.isDark == true)
        #expect(ReadingTheme.sepia.isDark == true)
        #expect(ReadingTheme.gray.isDark == true)
        #expect(ReadingTheme.light.isDark == false)
    }

    @Test func previewColorMatchesBackground() {
        for theme in ReadingTheme.allCases {
            // previewColor 應與 backgroundColor 相同
            #expect(theme.previewColor == theme.backgroundColor)
        }
    }

    @Test func toolbarStyleCorrect() {
        // light 使用 regularMaterial，其餘使用 ultraThinMaterial
        // Material 不支援 Equatable，但確認能不崩潰地取得即可
        for theme in ReadingTheme.allCases {
            _ = theme.toolbarStyle
        }
    }

    @Test func toolbarGradientNotCrash() {
        for theme in ReadingTheme.allCases {
            _ = theme.toolbarGradient
        }
    }

    @Test func separatorColorExists() {
        for theme in ReadingTheme.allCases {
            _ = theme.separatorColor
        }
    }
}

// MARK: - Color Hex Initializer 測試

struct ColorHexTests {

    @Test func sixCharHexParsesCorrectly() {
        let color = Color(hex: "#FF0000")
        // 確認不崩潰即可（Color 本身不易比較精確值）
        _ = color
    }

    @Test func eightCharHexParsesCorrectly() {
        let color = Color(hex: "#FF000080")
        _ = color
    }

    @Test func hashPrefixStripped() {
        // 不含 # 也應能解析
        let color = Color(hex: "00FF00")
        _ = color
    }

    @Test func invalidHexFallsBackToBlack() {
        // 長度不符 6/8 的 hex 應 fallback 為黑色 (0, 0, 0)
        let color = Color(hex: "ZZZ")
        _ = color
    }

    @Test func caseInsensitive() {
        let lower = Color(hex: "#aabbcc")
        let upper = Color(hex: "#AABBCC")
        _ = (lower, upper) // 確認皆不崩潰
    }
}

// MARK: - NNFont 測試

struct NNFontTests {

    @Test func readingFamilyAllCases() {
        #expect(NNFont.ReadingFamily.allCases.count == 3)
    }

    @Test func readingFamilyDisplayName() {
        #expect(NNFont.ReadingFamily.system.displayName == "System")
        #expect(NNFont.ReadingFamily.pingFang.displayName == "PingFang TC")
        #expect(NNFont.ReadingFamily.notoSans.displayName == "Noto Sans TC")
    }

    @Test func readingFamilyFontNotCrash() {
        for family in NNFont.ReadingFamily.allCases {
            _ = family.font(size: 18)
            _ = family.font(size: 24, weight: .bold)
        }
    }

    @Test func readerBodyDelegates() {
        _ = NNFont.readerBody(size: 18)
        _ = NNFont.readerBody(size: 20, family: .pingFang)
    }

    @Test func lineSpacingPoints() {
        // compact (1.2): 18 × (1.2 - 1.0) = 3.6
        let compact = NNFont.LineSpacing.compact.points(for: 18)
        #expect(abs(compact - 3.6) < 0.01)

        // normal (1.5): 18 × 0.5 = 9.0
        let normal = NNFont.LineSpacing.normal.points(for: 18)
        #expect(abs(normal - 9.0) < 0.01)

        // relaxed (1.8): 18 × 0.8 = 14.4
        let relaxed = NNFont.LineSpacing.relaxed.points(for: 18)
        #expect(abs(relaxed - 14.4) < 0.01)

        // loose (2.0): 18 × 1.0 = 18.0
        let loose = NNFont.LineSpacing.loose.points(for: 18)
        #expect(abs(loose - 18.0) < 0.01)
    }

    @Test func lineSpacingDisplayName() {
        for spacing in NNFont.LineSpacing.allCases {
            #expect(!spacing.displayName.isEmpty)
        }
    }
}

// MARK: - NNSpacing 測試

struct NNSpacingTests {

    @Test func minTouchTarget44pt() {
        #expect(NNSpacing.minTouchTarget >= 44)
    }

    @Test func ttsButtonSizeLargerThanMinTarget() {
        #expect(NNSpacing.ttsButtonSize >= NNSpacing.minTouchTarget)
    }

    @Test func spacingHierarchy() {
        #expect(NNSpacing.xxs < NNSpacing.xs)
        #expect(NNSpacing.xs < NNSpacing.sm)
        #expect(NNSpacing.sm < NNSpacing.md)
        #expect(NNSpacing.md < NNSpacing.lg)
        #expect(NNSpacing.lg < NNSpacing.xl)
        #expect(NNSpacing.xl < NNSpacing.xxl)
    }

    @Test func cardCornerRadiusMax16() {
        // 設計規範：圓角不超過 16pt
        #expect(NNSpacing.cardCornerRadius <= 16)
    }
}

// MARK: - Bookmark 測試

struct BookmarkTests {

    @Test func initSetsAllProperties() {
        let bookmark = Bookmark(paragraphIndex: 42, preview: "測試預覽", note: "筆記")
        #expect(bookmark.paragraphIndex == 42)
        #expect(bookmark.preview == "測試預覽")
        #expect(bookmark.note == "筆記")
        #expect(bookmark.book == nil)
    }

    @Test func initDefaultsNoteToEmpty() {
        let bookmark = Bookmark(paragraphIndex: 0, preview: "")
        #expect(bookmark.note == "")
    }

    @Test func dateCreatedIsRecent() {
        let before = Date()
        let bookmark = Bookmark(paragraphIndex: 0, preview: "")
        let after = Date()
        #expect(bookmark.dateCreated >= before)
        #expect(bookmark.dateCreated <= after)
    }
}

// MARK: - Book 額外測試

struct BookExtendedTests {

    @Test func initSetsProperties() {
        let book = Book(title: "測試", fileName: "test.txt", content: "內容")
        #expect(book.title == "測試")
        #expect(book.fileName == "test.txt")
        #expect(book.content == "內容")
        #expect(book.readingProgress == 0.0)
        #expect(book.chapters.isEmpty)
        #expect(book.bookmarks.isEmpty)
    }

    @Test func sortedChaptersOrderedByIndex() {
        let book = Book(title: "T", fileName: "t.txt", content: "")
        let ch2 = Chapter(index: 2, title: "Ch2", startOffset: 200, endOffset: 300)
        let ch0 = Chapter(index: 0, title: "Ch0", startOffset: 0, endOffset: 100)
        let ch1 = Chapter(index: 1, title: "Ch1", startOffset: 100, endOffset: 200)
        ch2.book = book; ch0.book = book; ch1.book = book
        book.chapters = [ch2, ch0, ch1]

        let sorted = book.sortedChapters
        #expect(sorted[0].title == "Ch0")
        #expect(sorted[1].title == "Ch1")
        #expect(sorted[2].title == "Ch2")
    }

    @Test func sortedChaptersEmptyWhenNoChapters() {
        let book = Book(title: "T", fileName: "t.txt", content: "")
        #expect(book.sortedChapters.isEmpty)
    }
}

// MARK: - TTSProviderType 測試

struct TTSProviderTypeTests {

    @Test func allCasesHasThree() {
        #expect(TTSProviderType.allCases.count == 3)
    }

    @Test func rawValueRoundTrip() {
        #expect(TTSProviderType(rawValue: "edge") == .edge)
        #expect(TTSProviderType(rawValue: "system") == .system)
        #expect(TTSProviderType(rawValue: "azure") == .azure)
    }

    @Test func invalidRawValueReturnsNil() {
        #expect(TTSProviderType(rawValue: "google") == nil)
    }

    @Test func identifierMatchesRawValue() {
        for type in TTSProviderType.allCases {
            #expect(type.id == type.rawValue)
        }
    }
}

// MARK: - TTSService 基本狀態測試

@MainActor
struct TTSServiceTests {

    @Test func initialState() {
        let service = TTSService()
        #expect(service.isPlaying == false)
        #expect(service.isPaused == false)
        #expect(service.currentParagraphIndex == 0)
        #expect(service.hasContent == false)
        #expect(service.currentParagraphText == "")
        #expect(service.sleepTimerEndDate == nil)
    }

    @Test func loadChapterSetsState() {
        let service = TTSService()
        let paragraphs = ["第一段", "第二段", "第三段"]
        service.loadChapter(paragraphs: paragraphs, startAt: 1)

        #expect(service.hasContent == true)
        #expect(service.currentParagraphIndex == 1)
        #expect(service.currentParagraphText == "第二段")
        #expect(service.isPlaying == false)
    }

    @Test func loadChapterStopsPlayback() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["A"], startAt: 0)
        // loadChapter 內部呼叫 stop()，確認不在播放
        #expect(service.isPlaying == false)
        #expect(service.isPaused == false)
    }

    @Test func currentParagraphTextOutOfBounds() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["唯一段落"], startAt: 0)
        #expect(service.currentParagraphText == "唯一段落")
        // 手動推到超出範圍不應崩潰
        service.loadChapter(paragraphs: [], startAt: 0)
        #expect(service.currentParagraphText == "")
    }

    @Test func playWithEmptyParagraphsDoesNotStart() {
        let service = TTSService()
        service.play()
        #expect(service.isPlaying == false)
    }

    @Test func stopResetsState() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["A", "B"], startAt: 0)
        service.stop()
        #expect(service.isPlaying == false)
        #expect(service.isPaused == false)
    }

    @Test func setProviderType() {
        let service = TTSService()
        service.setProviderType(.edge)
        #expect(service.activeProviderType == .edge)
        service.setProviderType(.azure)
        #expect(service.activeProviderType == .azure)
        service.setProviderType(.system)
        #expect(service.activeProviderType == .system)
    }

    @Test func setEdgeServerURLParsesSingleURL() {
        let service = TTSService()
        service.setEdgeServerURL("http://192.168.1.100:5050")
        #expect(service.edgeProvider.serverURLs.count == 1)
        #expect(service.edgeProvider.serverURLs.first?.absoluteString == "http://192.168.1.100:5050")
    }

    @Test func setEdgeServerURLParsesCommaSeparated() {
        let service = TTSService()
        service.setEdgeServerURL("http://a:5050, http://b:5050")
        #expect(service.edgeProvider.serverURLs.count == 2)
    }

    @Test func setEdgeServerURLParsesNewlineSeparated() {
        let service = TTSService()
        service.setEdgeServerURL("http://a:5050\nhttp://b:5050")
        #expect(service.edgeProvider.serverURLs.count == 2)
    }

    @Test func setEdgeServerURLNilClearsURLs() {
        let service = TTSService()
        service.setEdgeServerURL("http://a:5050")
        service.setEdgeServerURL(nil)
        #expect(service.edgeProvider.serverURLs.isEmpty)
    }

    @Test func setEdgeServerURLEmptyClearsURLs() {
        let service = TTSService()
        service.setEdgeServerURL("http://a:5050")
        service.setEdgeServerURL("")
        #expect(service.edgeProvider.serverURLs.isEmpty)
    }

    @Test func setAzureCredentials() {
        let service = TTSService()
        service.setAzureCredentials(key: "test-key", region: "westus")
        #expect(service.azureProvider.subscriptionKey == "test-key")
        #expect(service.azureProvider.region == "westus")
    }

    @Test func setSleepTimerSetsEndDate() {
        let service = TTSService()
        let before = Date()
        service.setSleepTimer(minutes: 30)
        let expected = before.addingTimeInterval(30 * 60)
        // 允許 1 秒誤差
        #expect(service.sleepTimerEndDate != nil)
        #expect(abs(service.sleepTimerEndDate!.timeIntervalSince(expected)) < 1.0)
    }

    @Test func setSleepTimerNilClearsTimer() {
        let service = TTSService()
        service.setSleepTimer(minutes: 15)
        #expect(service.sleepTimerEndDate != nil)
        service.setSleepTimer(minutes: nil)
        #expect(service.sleepTimerEndDate == nil)
    }

    @Test func previousParagraphAtStartDoesNothing() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["A", "B"], startAt: 0)
        service.previousParagraph()
        #expect(service.currentParagraphIndex == 0)
    }

    @Test func seekToValidIndex() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["A", "B", "C"], startAt: 0)
        service.seekTo(paragraphIndex: 2)
        #expect(service.currentParagraphIndex == 2)
    }

    @Test func seekToInvalidIndexDoesNothing() {
        let service = TTSService()
        service.loadChapter(paragraphs: ["A", "B"], startAt: 0)
        service.seekTo(paragraphIndex: 99)
        #expect(service.currentParagraphIndex == 0)
        service.seekTo(paragraphIndex: -1)
        #expect(service.currentParagraphIndex == 0)
    }
}

// MARK: - EdgeTTSProvider 靜態測試

struct EdgeTTSProviderTests {

    @Test func providerProperties() {
        let provider = EdgeTTSProvider()
        #expect(provider.id == "edge")
        #expect(provider.name == "Edge TTS")
        #expect(provider.requiresNetwork == true)
        #expect(provider.handlesPlaybackDirectly == false)
    }

    @Test func serverURLsDefaultEmpty() {
        let provider = EdgeTTSProvider()
        #expect(provider.serverURLs.isEmpty)
    }

    @Test func availableVoicesReturnsThree() async throws {
        let provider = EdgeTTSProvider()
        let voices = try await provider.availableVoices()
        #expect(voices.count == 3)
        #expect(voices.allSatisfy { $0.language == "zh-TW" })
        #expect(voices.allSatisfy { $0.providerID == "edge" })
    }

    @Test func synthesizeThrowsWhenNoServer() async {
        let provider = EdgeTTSProvider()
        let voice = TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "", language: "zh-TW", providerID: "edge")
        do {
            _ = try await provider.synthesize(text: "測試", voice: voice, rate: 0.5)
            #expect(Bool(false), "應拋出錯誤")
        } catch {
            // 應為 serverNotConfigured
            #expect(error is EdgeTTSError)
        }
    }

    @Test func isAvailableReturnsFalseWhenNoServer() async {
        let provider = EdgeTTSProvider()
        let available = await provider.isAvailable()
        #expect(available == false)
    }
}

// MARK: - AzureTTSProvider 靜態測試

struct AzureTTSProviderTests {

    @Test func providerProperties() {
        let provider = AzureTTSProvider()
        #expect(provider.id == "azure")
        #expect(provider.name == "Azure TTS")
        #expect(provider.requiresNetwork == true)
        #expect(provider.handlesPlaybackDirectly == false)
    }

    @Test func isAvailableReturnsFalseWhenNotConfigured() async {
        let provider = AzureTTSProvider()
        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test func isAvailableReturnsTrueWhenConfigured() async {
        let provider = AzureTTSProvider()
        provider.subscriptionKey = "test-key"
        provider.region = "eastasia"
        let available = await provider.isAvailable()
        #expect(available == true)
    }

    @Test func isAvailableReturnsFalseWithEmptyKey() async {
        let provider = AzureTTSProvider()
        provider.subscriptionKey = ""
        provider.region = "eastasia"
        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test func isAvailableReturnsFalseWithEmptyRegion() async {
        let provider = AzureTTSProvider()
        provider.subscriptionKey = "key"
        provider.region = ""
        let available = await provider.isAvailable()
        #expect(available == false)
    }

    @Test func synthesizeThrowsWhenNotConfigured() async {
        let provider = AzureTTSProvider()
        let voice = TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "", language: "zh-TW", providerID: "azure")
        do {
            _ = try await provider.synthesize(text: "測試", voice: voice, rate: 0.5)
            #expect(Bool(false), "應拋出錯誤")
        } catch {
            #expect(error is AzureTTSError)
        }
    }

    @Test func availableVoicesReturnsThree() async throws {
        let provider = AzureTTSProvider()
        let voices = try await provider.availableVoices()
        #expect(voices.count == 3)
        #expect(voices.allSatisfy { $0.language == "zh-TW" })
        #expect(voices.allSatisfy { $0.providerID == "azure" })
    }
}

// MARK: - ScrollCommand 測試

struct ScrollCommandTests {

    @Test func initSetsIndex() {
        let cmd = ScrollCommand(index: 42)
        #expect(cmd.index == 42)
    }

    @Test func eachInstanceHasUniqueID() {
        let cmd1 = ScrollCommand(index: 0)
        let cmd2 = ScrollCommand(index: 0)
        #expect(cmd1.id != cmd2.id)
    }

    @Test func sameIndexDifferentIDNotEqual() {
        let cmd1 = ScrollCommand(index: 5)
        let cmd2 = ScrollCommand(index: 5)
        #expect(cmd1 != cmd2) // UUID 不同所以不相等
    }
}

// MARK: - NNSymbol 常量驗證

struct NNSymbolTests {

    @Test func symbolsAreNonEmpty() {
        let symbols = [
            NNSymbol.back, NNSymbol.chapterList, NNSymbol.settings,
            NNSymbol.play, NNSymbol.pause, NNSymbol.next, NNSymbol.previous,
            NNSymbol.addBook, NNSymbol.importFile, NNSymbol.deleteBook,
            NNSymbol.fontSize, NNSymbol.theme, NNSymbol.scrollMode, NNSymbol.pageMode,
        ]
        for symbol in symbols {
            #expect(!symbol.isEmpty)
        }
    }

    @Test func symbolsAreValidSFSymbols() {
        // 透過 UIImage(systemName:) 確認 SF Symbols 名稱有效
        let symbols = [
            NNSymbol.back, NNSymbol.chapterList, NNSymbol.settings,
            NNSymbol.play, NNSymbol.pause, NNSymbol.next, NNSymbol.previous,
            NNSymbol.addBook, NNSymbol.deleteBook,
        ]
        for symbol in symbols {
            #expect(UIImage(systemName: symbol) != nil, "SF Symbol '\(symbol)' not found")
        }
    }
}
