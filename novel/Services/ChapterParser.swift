import Foundation

struct ChapterParser {
    /// 章節匹配的正則模式
    private static let patterns: [String] = [
        #"^第[零一二三四五六七八九十百千萬\d]+[章回節卷集篇]"#,
        #"^Chapter\s+\d+"#,
        #"^卷[零一二三四五六七八九十百千萬\d]+"#
    ]

    /// 從完整文字內容中解析章節
    static func parseChapters(from content: String) -> [Chapter] {
        let lines = content.components(separatedBy: .newlines)
        var chapterMarkers: [(title: String, utf16Offset: Int)] = []
        var currentUTF16Offset = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && isChapterTitle(trimmed) {
                chapterMarkers.append((title: trimmed, utf16Offset: currentUTF16Offset))
            }
            // 每行的 UTF-16 長度 + 換行符
            currentUTF16Offset += line.utf16.count + 1 // +1 for newline
        }

        let totalUTF16Length = content.utf16.count

        // 若找到章節標記，建立章節
        if !chapterMarkers.isEmpty {
            var chapters: [Chapter] = []
            for i in 0..<chapterMarkers.count {
                let start = chapterMarkers[i].utf16Offset
                let end = (i + 1 < chapterMarkers.count) ? chapterMarkers[i + 1].utf16Offset : totalUTF16Length
                let chapter = Chapter(
                    index: i,
                    title: chapterMarkers[i].title,
                    startOffset: start,
                    endOffset: end
                )
                chapters.append(chapter)
            }
            return chapters
        }

        // Fallback：依固定字元數分頁（每 3000 字）
        return chunkChapters(content: content, chunkSize: 3000)
    }

    /// 判斷一行文字是否為章節標題
    private static func isChapterTitle(_ line: String) -> Bool {
        for pattern in patterns {
            if let regex = try? Regex(pattern),
               line.firstMatch(of: regex) != nil {
                return true
            }
        }
        return false
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

            // 嘗試在段落邊界斷開
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
