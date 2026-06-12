import SwiftUI
import SwiftData

/// 書庫卡片：演算法生成封面、進度條、朗讀中指示
struct BookCardView: View {
    let book: Book
    let isPlaying: Bool
    var appearIndex: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    // MARK: - Cover

    private var coverPalette: (Color, Color) {
        let index = abs(book.title.hashValue) % NNColor.coverPalettes.count
        return NNColor.coverPalettes[index]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            coverArea
            infoArea
        }
        .background(NNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NNSpacing.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: NNSpacing.cardCornerRadius)
                .strokeBorder(
                    isPlaying
                        ? NNColor.accent.opacity(0.55)
                        : NNColor.separator.opacity(0.5),
                    lineWidth: isPlaying ? 1.5 : 0.5
                )
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
        .blur(radius: appeared || reduceMotion ? 0 : 4)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            let anim: Animation = reduceMotion ? .linear(duration: 0) : NNAnimation.inkDrop(index: appearIndex)
            withAnimation(anim) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(book.title)，閱讀進度\(Int(book.readingProgress * 100))%\(isPlaying ? "，朗讀中" : "")"
        )
    }

    // MARK: - Cover Area

    private var coverArea: some View {
        ZStack {
            // 遠山水墨封面（依書名生成獨特山形 + 直排題簽）
            InkCoverView(title: book.title, palette: coverPalette)

            // 朗讀中：左上角朱砂「聽」印 + 墨波
            if isPlaying {
                VStack {
                    HStack(spacing: 5) {
                        SealView(text: "聽", size: 22)
                        InkWaveform(isAnimating: true, maxHeight: 12)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(NNColor.cardBackground.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(height: 108)
    }

    // MARK: - Info Area

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: NNSpacing.xs) {
            // 書名（宋體題字）
            Text(book.title)
                .font(NNFont.inkTitle(size: 14))
                .foregroundStyle(NNColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 毛筆筆觸進度條
            InkProgressBar(progress: book.readingProgress, height: 2)

            // 進度 % + 狀態標籤
            HStack(alignment: .center) {
                Text("\(Int(book.readingProgress * 100))%")
                    .font(NNFont.uiCaption2)
                    .foregroundStyle(NNColor.textSecondary)

                Spacer()

                if isPlaying {
                    Text("朗讀中")
                        .font(NNFont.uiCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(NNColor.accent)
                } else {
                    Text(relativeDate)
                        .font(NNFont.uiCaption2)
                        .foregroundStyle(NNColor.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, NNSpacing.cardPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh-TW")
        f.unitsStyle = .abbreviated
        return f
    }()

    private var relativeDate: String {
        Self.relativeDateFormatter.localizedString(for: book.dateLastRead, relativeTo: Date())
    }
}
