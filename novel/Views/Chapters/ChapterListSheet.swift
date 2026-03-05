import SwiftUI

/// 章節目錄列表
struct ChapterListSheet: View {
    let chapters: [Chapter]
    let currentChapterIndex: Int
    let onChapterSelected: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.index) { offset, chapter in
                    Button {
                        onChapterSelected(offset)
                        dismiss()
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .foregroundStyle(
                                    offset == currentChapterIndex
                                        ? Color.accentColor
                                        : Color.primary
                                )
                                .fontWeight(offset == currentChapterIndex ? .semibold : .regular)

                            Spacer()

                            if offset == currentChapterIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("目錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}
