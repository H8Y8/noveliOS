import Foundation

struct ChapterParser {
    /// 按優先順序排列的章節 pattern。
    /// parseChapters 會依序嘗試每個 pattern，使用第一個能找到足夠章節的 pattern，避免混用造成重複。
    private static let orderedPatterns: [(pattern: String, hasNumberPrefix: Bool)] = [
        // 帶數字前綴：「1. 第一章 ...」（最可靠，優先使用）
        (#"^\d+\.\s+第[零一二三四五六七八九十百千萬\d]+[章回節卷集篇]"#, true),
        // 純章節標題：「第一章 ...」、「第146章 ...」
        (#"^第[零一二三四五六七八九十百千萬\d]+[章回節卷集篇]"#, false),
        // 英文章節：「Chapter 1」
        (#"^Chapter\s+\d+"#, false),
        // 卷：「卷一」
        (#"^卷[零一二三四五六七八九十百千萬\d]+"#, false),
    ]

    private static let minimumChapterCount = 2

    /// 從完整文字內容中解析章節
    static func parseChapters(from content: String) -> [Chapter] {
        let lines = content.components(separatedBy: .newlines)

        // 依序嘗試每個 pattern，第一個找到足夠章節數的就採用
        for (pattern, hasNumberPrefix) in orderedPatterns {
            guard let regex = try? Regex(pattern) else { continue }
            let markers = extractMarkers(from: lines, regex: regex, hasNumberPrefix: hasNumberPrefix)
            if markers.count >= minimumChapterCount {
                return buildChapters(from: markers, totalUTF16Length: content.utf16.count)
            }
        }

        // Fallback：依固定字元數分頁（每 3000 字）
        return chunkChapters(content: content, chunkSize: 3000)
    }

    // MARK: - Private Helpers

    /// 用指定的 regex 掃描所有行，回傳 (title, utf16Offset) 的列表
    private static func extractMarkers(
        from lines: [String],
        regex: Regex<AnyRegexOutput>,
        hasNumberPrefix: Bool
    ) -> [(title: String, utf16Offset: Int)] {
        var markers: [(title: String, utf16Offset: Int)] = []
        var currentUTF16Offset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, trimmed.firstMatch(of: regex) != nil {
                let title: String
                if hasNumberPrefix, let 第Idx = trimmed.range(of: "第") {
                    // 去掉「1. 」前綴，只保留「第一章 ...」
                    title = String(trimmed[第Idx.lowerBound...])
                } else {
                    title = trimmed
                }
                markers.append((title: title, utf16Offset: currentUTF16Offset))
            }
            currentUTF16Offset += line.utf16.count + 1 // +1 for \n
        }

        return markers
    }

    /// 將 markers 轉換為 Chapter 物件列表
    private static func buildChapters(
        from markers: [(title: String, utf16Offset: Int)],
        totalUTF16Length: Int
    ) -> [Chapter] {
        var chapters: [Chapter] = []
        for i in 0..<markers.count {
            let start = markers[i].utf16Offset
            let end = (i + 1 < markers.count) ? markers[i + 1].utf16Offset : totalUTF16Length
            let chapter = Chapter(
                index: i,
                title: markers[i].title,
                startOffset: start,
                endOffset: end
            )
            chapters.append(chapter)
        }
        return chapters
    }

    /// Fallback：將內容依固定字元數分割為章節
    private static func chunkChapters(content: String, chunkSize: Int) -> [Chapter] {
        let totalLength = content.utf16.count
        guard totalLength > 0 else { return [] }

        var chapters: [Chapter] = []
        var offset = 0
        var index = 0

        while offset < totalLength {
            var end = min(offset + chunkSize, totalLength)

            if end < totalLength {
                let searchStart = max(offset + chunkSize - 200, offset)
                let utf16 = content.utf16
                if let startIdx = utf16.index(utf16.startIndex, offsetBy: searchStart, limitedBy: utf16.endIndex),
                   let endIdx = utf16.index(utf16.startIndex, offsetBy: end, limitedBy: utf16.endIndex) {
                    let searchRange = String(utf16[startIdx..<endIdx]) ?? ""
                    if let newlineRange = searchRange.range(of: "\n", options: .backwards) {
                        let newlineUTF16Offset = searchRange.utf16.distance(
                            from: searchRange.utf16.startIndex,
                            to: newlineRange.lowerBound.samePosition(in: searchRange.utf16) ?? searchRange.utf16.startIndex
                        )
                        end = searchStart + newlineUTF16Offset + 1
                    }
                }
            }

            let chapter = Chapter(
                index: index,
                title: "第 \(index + 1) 頁",
                startOffset: offset,
                endOffset: end
            )
            chapters.append(chapter)
            offset = end
            index += 1
        }

        return chapters
    }
}
