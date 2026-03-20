//
//  novelTests.swift
//  novelTests
//
//  Created by 陳奕顯 on 2026/3/4.
//

import Testing
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
