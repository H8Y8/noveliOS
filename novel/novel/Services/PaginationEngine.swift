import UIKit

/// 文字分頁引擎：根據字型設定與可用空間，計算每頁應顯示的段落索引
struct PaginationEngine {

    /// 計算分頁結果
    /// - Parameters:
    ///   - paragraphs: 全書段落文字陣列
    ///   - fontSize: 字型大小（pt）
    ///   - lineSpacing: 行距乘數（如 1.5）
    ///   - fontFamily: 字體名稱（"System"、"PingFang TC"、"Noto Sans TC"）
    ///   - availableSize: 文字可用區域（已扣除工具列、頁碼等邊距）
    /// - Returns: 二維陣列，外層為頁，內層為該頁包含的段落索引
    static func paginate(
        paragraphs: [String],
        fontSize: Double,
        lineSpacing: Double,
        fontFamily: String,
        availableSize: CGSize
    ) -> [[Int]] {
        guard !paragraphs.isEmpty,
              availableSize.width > 0,
              availableSize.height > 0 else {
            return paragraphs.isEmpty ? [] : [Array(0..<paragraphs.count)]
        }

        let font = makeUIFont(fontSize: fontSize, fontFamily: fontFamily)
        let lineSpacingPts = CGFloat(fontSize) * CGFloat(lineSpacing - 1.0)
        let paragraphSpacing = CGFloat(fontSize) * 0.55 + 4
        let verticalPadding = NNSpacing.xxs * 2 // 段落上下 padding

        // 建立共用 attributes（避免每段重建 NSMutableParagraphStyle）
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacingPts
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        var pages: [[Int]] = []
        var currentPage: [Int] = []
        var currentHeight: CGFloat = 0

        for i in 0..<paragraphs.count {
            let textHeight = measureParagraph(
                text: paragraphs[i],
                attributes: attributes,
                maxWidth: availableSize.width
            ) + verticalPadding

            let neededHeight = currentPage.isEmpty
                ? textHeight
                : paragraphSpacing + textHeight

            if currentHeight + neededHeight > availableSize.height && !currentPage.isEmpty {
                pages.append(currentPage)
                currentPage = [i]
                currentHeight = textHeight
            } else {
                currentPage.append(i)
                currentHeight += neededHeight
            }
        }

        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        return pages
    }

    /// 找出指定段落索引所在的頁碼（0-based），使用二分搜尋
    static func pageIndex(forParagraph paragraphIndex: Int, in pages: [[Int]]) -> Int {
        guard !pages.isEmpty else { return 0 }
        var lo = 0, hi = pages.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            guard let first = pages[mid].first, let last = pages[mid].last else { break }
            if paragraphIndex < first { hi = mid - 1 }
            else if paragraphIndex > last { lo = mid + 1 }
            else { return mid }
        }
        return max(pages.count - 1, 0)
    }

    // MARK: - Private

    private static func measureParagraph(
        text: String,
        attributes: [NSAttributedString.Key: Any],
        maxWidth: CGFloat
    ) -> CGFloat {
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return ceil(boundingRect.height)
    }

    private static func makeUIFont(fontSize: Double, fontFamily: String) -> UIFont {
        switch fontFamily {
        case "PingFang TC":
            return UIFont(name: "PingFangTC-Regular", size: fontSize)
                ?? .systemFont(ofSize: fontSize)
        case "Noto Sans TC":
            return UIFont(name: "NotoSansTC-Regular", size: fontSize)
                ?? .systemFont(ofSize: fontSize)
        default:
            return .systemFont(ofSize: fontSize)
        }
    }
}
