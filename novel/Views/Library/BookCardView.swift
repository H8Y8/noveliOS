import SwiftUI
import SwiftData

/// 書庫列表中的單本書籍卡片
struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                // 閱讀進度
                ProgressView(value: book.readingProgress)
                    .tint(.accentColor)

                Text("\(Int(book.readingProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("最後閱讀：\(book.dateLastRead.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title)，閱讀進度\(Int(book.readingProgress * 100))%")
    }
}
