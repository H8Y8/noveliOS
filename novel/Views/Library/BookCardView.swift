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

    private var titleMonogram: String {
        String(book.title.prefix(1))
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
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            let anim: Animation = reduceMotion ? .linear(duration: 0) : NNAnimation.cardAppear(index: appearIndex)
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
            // 演算法漸層封面
            LinearGradient(
                colors: [coverPalette.0, coverPalette.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 書名首字做大字裝飾（低透明度，呈現質感而不搶焦）
            Text(titleMonogram)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.white.opacity(0.16))

            // 朗讀中：右上角聲波徽章
            if isPlaying {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NNColor.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .symbolEffect(.variableColor.iterative, options: .repeating)
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
            // 書名
            Text(book.title)
                .font(NNFont.uiSubheadline)
                .fontWeight(.medium)
                .foregroundStyle(NNColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 細進度條
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NNColor.progressTrack)
                        .frame(height: 2)
                    Capsule()
                        .fill(NNColor.progressFill)
                        .frame(
                            width: max(geo.size.width * book.readingProgress, 0),
                            height: 2
                        )
                }
            }
            .frame(height: 2)

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
