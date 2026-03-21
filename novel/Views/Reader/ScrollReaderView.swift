import SwiftUI

/// 程式化捲動指令，每次建立都有唯一 UUID 以確保相同 index 也能觸發
struct ScrollCommand: Equatable {
    let id: UUID
    let index: Int
    init(index: Int) {
        self.id = UUID()
        self.index = index
    }
}

/// 捲動式閱讀內容視圖（全書連貫模式）
/// - 顯示整本書所有段落，不分章節
/// - TTS 高亮透過柔和動畫切換
/// - 頂底預留工具列高度，確保首末段落不被遮擋
struct ScrollReaderView: View {
    let paragraphs: [String]
    let theme: ReadingTheme
    let fontSize: Double
    let lineSpacing: Double
    let fontFamily: String
    let highlightedParagraphIndex: Int?
    @Binding var visibleParagraphIndex: Int
    @Binding var scrollCommand: ScrollCommand?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: paragraphSpacing) {
                    // 頂部安全距離（工具列高 + 漸層高 + 呼吸空間）
                    Color.clear.frame(height: NNSpacing.toolbarHeight + 28 + NNSpacing.md)

                    ForEach(0..<paragraphs.count, id: \.self) { index in
                        paragraphView(index: index, text: paragraphs[index])
                    }

                    // 底部安全距離（底部工具列淨空）
                    Color.clear.frame(height: NNSpacing.bottomToolbarHeight + 32 + NNSpacing.md)
                }
            }
            .onChange(of: highlightedParagraphIndex) { _, newIndex in
                // TTS 推進時自動捲動至當前段落
                if let newIndex {
                    if reduceMotion {
                        proxy.scrollTo(newIndex, anchor: .center)
                    } else {
                        withAnimation(NNAnimation.ttsHighlight) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: scrollCommand) { _, cmd in
                // 程式化跳轉（章節目錄選擇）
                if let cmd {
                    proxy.scrollTo(cmd.index, anchor: .top)
                }
            }
            .onAppear {
                // 恢復上次閱讀位置（不含動畫，避免啟動時畫面閃跳）
                if visibleParagraphIndex > 0, visibleParagraphIndex < paragraphs.count {
                    proxy.scrollTo(visibleParagraphIndex, anchor: .top)
                }
            }
        }
    }

    // MARK: - Paragraph View

    @ViewBuilder
    private func paragraphView(index: Int, text: String) -> some View {
        let isHighlighted = index == highlightedParagraphIndex

        Text(text)
            .font(readerFont)
            .foregroundStyle(theme.textColor)
            .lineSpacing(lineSpacingPoints)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, NNSpacing.readerHorizontal)
            .padding(.vertical, NNSpacing.xxs)
            // TTS 高亮：柔和圓角底色，使用主題定義的 highlightColor（非螢光）
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHighlighted ? theme.highlightColor : Color.clear)
                    .padding(.horizontal, NNSpacing.readerHorizontal - 6)
                    .animation(reduceMotion ? nil : NNAnimation.ttsHighlight, value: highlightedParagraphIndex)
            )
            .id(index)
            .onAppear {
                // 只在每5段或最末段更新，避免快速滾動時觸發寫入風暴
                if index % 5 == 0 || index == paragraphs.count - 1 {
                    visibleParagraphIndex = index
                }
            }
    }

    // MARK: - Computed Values

    /// 段落間距：字號 × 係數，讓中文段落呼吸感適中
    private var paragraphSpacing: CGFloat {
        CGFloat(fontSize) * 0.55 + 4
    }

    /// 行距點數：由乘數換算（1.2x ~ 2.0x）
    private var lineSpacingPoints: CGFloat {
        CGFloat(fontSize) * CGFloat(lineSpacing - 1.0)
    }

    /// 閱讀字體：透過 NNFont.ReadingFamily 對應，支援 System / PingFang TC / Noto Sans TC
    private var readerFont: Font {
        NNFont.readerBody(
            size: CGFloat(fontSize),
            family: NNFont.ReadingFamily(rawValue: fontFamily) ?? .system
        )
    }
}
