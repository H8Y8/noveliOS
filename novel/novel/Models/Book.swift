import Foundation
import SwiftData

@Model
class Book {
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String = ""
    @Attribute(.externalStorage) var content: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter] = []
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.book)
    var bookmarks: [Bookmark] = []
    var lastReadChapter: Int = 0
    var lastReadOffset: Int = 0
    var dateAdded: Date = Date()
    var dateLastRead: Date = Date()
    var readingProgress: Double = 0.0

    init(title: String, fileName: String, content: String) {
        self.id = UUID()
        self.title = title
        self.fileName = fileName
        self.content = content
        self.dateAdded = Date()
        self.dateLastRead = Date()
    }

    /// 取得指定章節的內容文字
    func chapterContent(at index: Int) -> String {
        guard index >= 0, index < chapters.count else { return "" }
        let sortedChapters = chapters.sorted { $0.index < $1.index }
        let chapter = sortedChapters[index]
        let utf16 = content.utf16
        guard let start = utf16.index(utf16.startIndex, offsetBy: chapter.startOffset, limitedBy: utf16.endIndex),
              let end = utf16.index(utf16.startIndex, offsetBy: chapter.endOffset, limitedBy: utf16.endIndex) else {
            return ""
        }
        return String(utf16[start..<end]) ?? ""
    }

    /// 排序後的章節列表
    var sortedChapters: [Chapter] {
        chapters.sorted { $0.index < $1.index }
    }
}
