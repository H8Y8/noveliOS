import Foundation
import SwiftData

@Model
class Bookmark {
    var id: UUID = UUID()
    /// 書籤對應的全書段落索引
    var paragraphIndex: Int = 0
    /// 使用者筆記（可選）
    var note: String = ""
    /// 段落內容預覽（儲存前 50 字供列表顯示）
    var preview: String = ""
    /// 建立時間
    var dateCreated: Date = Date()

    @Relationship var book: Book?

    init(paragraphIndex: Int, preview: String, note: String = "") {
        self.id = UUID()
        self.paragraphIndex = paragraphIndex
        self.preview = preview
        self.note = note
        self.dateCreated = Date()
    }
}
