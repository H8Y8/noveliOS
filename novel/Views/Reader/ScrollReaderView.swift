import SwiftUI

/// 捲動式閱讀內容視圖
struct ScrollReaderView: View {
    let paragraphs: [String]
    let theme: ReadingTheme
    let fontSize: Double
    let lineSpacing: Double
    let fontFamily: String
    let highlightedParagraphIndex: Int?
    @Binding var visibleParagraphIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: fontSize * 0.8) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(paragraph)
                            .font(readerFont)
                            .foregroundStyle(theme.textColor)
                            .lineSpacing(fontSize * (lineSpacing - 1.0))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                            .background(
                                index == highlightedParagraphIndex
                                    ? theme.highlightColor
                                    : Color.clear
                            )
                            .id(index)
                            .onAppear {
                                visibleParagraphIndex = index
                            }
                    }
                }
                .padding(.vertical, 20)
            }
            .onChange(of: highlightedParagraphIndex) { _, newIndex in
                if let newIndex {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onAppear {
                // 恢復上次閱讀位置
                if visibleParagraphIndex > 0 && visibleParagraphIndex < paragraphs.count {
                    proxy.scrollTo(visibleParagraphIndex, anchor: .top)
                }
            }
        }
    }

    private var readerFont: Font {
        switch fontFamily {
        case "PingFang TC":
            return .custom("PingFangTC-Regular", size: fontSize)
        default:
            return .system(size: fontSize)
        }
    }
}
