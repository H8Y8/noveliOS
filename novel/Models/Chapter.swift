import Foundation
import SwiftData

@Model
class Chapter {
    var index: Int = 0
    var title: String = ""
    var startOffset: Int = 0
    var endOffset: Int = 0
    var book: Book?

    init(index: Int, title: String, startOffset: Int, endOffset: Int) {
        self.index = index
        self.title = title
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}
