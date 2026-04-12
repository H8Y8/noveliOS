import SwiftUI
import SwiftData

/// 書籤列表面板：顯示所有書籤，點擊跳轉，滑動刪除
struct BookmarkListSheet: View {
    let book: Book
    let onBookmarkSelected: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedBookmarks: [Bookmark] {
        book.bookmarks.sorted { $0.paragraphIndex < $1.paragraphIndex }
    }

    var body: some View {
        ZStack {
            NNColor.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 標題列
                HStack {
                    Text("書籤")
                        .font(NNFont.uiHeadline)
                        .foregroundStyle(NNColor.textPrimary)
                    Spacer()
                    Text("\(sortedBookmarks.count)")
                        .font(NNFont.uiCaption)
                        .foregroundStyle(NNColor.textTertiary)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(NNColor.textTertiary)
                            .frame(width: NNSpacing.minTouchTarget, height: NNSpacing.minTouchTarget)
                    }
                    .accessibilityLabel("關閉書籤")
                }
                .padding(.horizontal, NNSpacing.lg)
                .padding(.vertical, NNSpacing.sm)

                if sortedBookmarks.isEmpty {
                    emptyState
                } else {
                    bookmarkList
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(NNColor.appBackground)
    }

    private var emptyState: some View {
        VStack(spacing: NNSpacing.md) {
            Spacer()
            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(NNColor.textTertiary)
            Text("尚無書籤")
                .font(NNFont.uiBody)
                .foregroundStyle(NNColor.textSecondary)
            Text("長按段落可新增書籤")
                .font(NNFont.uiCaption)
                .foregroundStyle(NNColor.textTertiary)
            Spacer()
        }
    }

    private var bookmarkList: some View {
        List {
            ForEach(sortedBookmarks) { bookmark in
                Button {
                    dismiss()
                    onBookmarkSelected(bookmark.paragraphIndex)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookmark.preview)
                            .font(NNFont.uiBody)
                            .foregroundStyle(NNColor.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: NNSpacing.sm) {
                            Label("第 \(bookmark.paragraphIndex + 1) 段", systemImage: "bookmark.fill")
                                .font(NNFont.uiCaption2)
                                .foregroundStyle(NNColor.accent)

                            if !bookmark.note.isEmpty {
                                Text(bookmark.note)
                                    .font(NNFont.uiCaption2)
                                    .foregroundStyle(NNColor.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(bookmark.dateCreated, style: .date)
                                .font(NNFont.uiCaption2)
                                .foregroundStyle(NNColor.textTertiary)
                        }
                    }
                    .padding(.vertical, NNSpacing.xs)
                }
                .listRowBackground(NNColor.cardBackground)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let bookmark = sortedBookmarks[index]
                    modelContext.delete(bookmark)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
