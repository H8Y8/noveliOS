import SwiftUI
import UIKit

// MARK: - 水墨元件庫「墨韻」
// 六個共用元件：宣紙紋理、墨暈按壓、水墨封面、朱砂印章、毛筆進度條、墨波聲紋。
// 全部使用 SwiftUI 原生 API 與 Canvas/CoreGraphics，不引入第三方資源。

// MARK: - 確定性偽隨機（LCG）
// 紋理與封面需要可重現的隨機，避免每次重繪閃變。

struct InkRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// 回傳 0..<1 的 Double
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - 宣紙紋理

enum InkPaperTexture {

    /// 256×256 可平鋪的宣紙纖維噪點圖，只生成一次。
    static let sharedImage: UIImage = {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            var rng = InkRandom(seed: 0x58A8)   // 「墨」
            let cg = ctx.cgContext
            // 細噪點（紙纖維顆粒）
            for _ in 0..<900 {
                let x = rng.next(in: 0...255)
                let y = rng.next(in: 0...255)
                let r = rng.next(in: 0.3...0.9)
                let gray = rng.next(in: 0...1) > 0.5 ? 1.0 : 0.0
                cg.setFillColor(UIColor(white: gray, alpha: rng.next(in: 0.25...0.6)).cgColor)
                cg.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
            // 少量長纖維（短弧線）
            for _ in 0..<40 {
                let x = rng.next(in: 0...255)
                let y = rng.next(in: 0...255)
                let len = rng.next(in: 4...14)
                let angle = rng.next(in: 0...(2 * .pi))
                cg.setStrokeColor(UIColor(white: 0.5, alpha: 0.18).cgColor)
                cg.setLineWidth(0.4)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len))
                cg.strokePath()
            }
        }
    }()
}

extension View {
    /// 鋪上宣紙纖維紋理（極低透明度，僅提供質感不干擾閱讀）
    func inkPaper(opacity: Double = 0.04) -> some View {
        overlay(
            Image(uiImage: InkPaperTexture.sharedImage)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

// MARK: - 墨暈按壓 ButtonStyle

/// 按下時自中心暈開一圈淡墨。`reduceMotion` 時降級為透明度變化。
struct InkButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(NNColor.textPrimary.opacity(configuration.isPressed ? 0.12 : 0))
                    .scaleEffect(configuration.isPressed ? 1.2 : 0.4)
                    .animation(reduceMotion ? nil : NNAnimation.inkSpread,
                               value: configuration.isPressed)
            )
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(NNAnimation.micro, value: configuration.isPressed)
    }
}

/// 卡片用：輕微縮放 + 墨色加深，不暈圈。
struct InkScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(NNAnimation.micro, value: configuration.isPressed)
    }
}

// MARK: - 水墨封面（遠山剪影）

/// 依書名 hash 生成獨特的遠山水墨封面：2–3 層山形 + 漸層 + 留白 + 直排書名。
struct InkCoverView: View {
    let title: String
    let palette: (Color, Color)

    /// 穩定 hash（不可用 String.hashValue，跨啟動會變）
    private var seed: UInt64 {
        var h: UInt64 = 5381
        for byte in title.utf8 { h = (h << 5) &+ h &+ UInt64(byte) }
        return h
    }

    var body: some View {
        ZStack {
            // 天空留白：宣紙色微漸層
            LinearGradient(
                colors: [NNColor.cardBackground, palette.1.opacity(0.18)],
                startPoint: .top, endPoint: .bottom
            )

            // 遠山層疊
            Canvas { context, size in
                var rng = InkRandom(seed: seed)
                let layers = 2 + Int(rng.next() * 2)   // 2–3 層
                for layer in 0..<layers {
                    let depth = Double(layer) / Double(max(layers - 1, 1)) // 0 遠 → 1 近
                    let baseY = size.height * (0.45 + 0.22 * depth)
                    let amp = size.height * rng.next(in: 0.10...0.20) * (0.6 + 0.4 * depth)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: baseY + amp * rng.next(in: -0.5...0.5)))
                    let peaks = 2 + Int(rng.next() * 3)  // 2–4 個峰
                    let step = size.width / Double(peaks)
                    var x: Double = 0
                    for _ in 0..<peaks {
                        let nx = x + step
                        let peakX = x + step * rng.next(in: 0.3...0.7)
                        let peakY = baseY - amp * rng.next(in: 0.4...1.0)
                        let endY = baseY + amp * rng.next(in: -0.4...0.4)
                        path.addQuadCurve(
                            to: CGPoint(x: nx, y: endY),
                            control: CGPoint(x: peakX, y: peakY)
                        )
                        x = nx
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()

                    // 遠山淡、近山濃（墨分濃淡）
                    let shade = palette.0.opacity(0.35 + 0.55 * depth)
                    context.fill(path, with: .linearGradient(
                        Gradient(colors: [shade, palette.1.opacity(0.25 + 0.45 * depth)]),
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    ))
                }
            }

            // 直排書名（傳統書冊題簽式，右上）
            HStack {
                Spacer()
                VStack(spacing: 1) {
                    ForEach(Array(title.prefix(6).enumerated()), id: \.offset) { _, ch in
                        Text(String(ch))
                            .font(NNFont.inkTitle(size: 13, weight: .semibold))
                            .foregroundStyle(NNColor.textPrimary.opacity(0.82))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 5)
                .background(NNColor.cardBackground.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.trailing, 8)
                .padding(.top, 8)
            }
        }
        .inkPaper(opacity: 0.05)
        .accessibilityHidden(true)   // 書名由卡片整體 label 朗讀
    }
}

// MARK: - 朱砂印章

/// 圓角方印：朱砂底、宣紙色宋體字、細內框。1–2 字。
struct SealView: View {
    let text: String
    var size: CGFloat = 24

    var body: some View {
        Text(text)
            .font(NNFont.inkTitle(size: size * 0.52, weight: .bold))
            .foregroundStyle(Color(hex: "#F4EFE6"))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.16)
                    .fill(NNColor.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.16)
                    .inset(by: size * 0.08)
                    .strokeBorder(Color(hex: "#F4EFE6").opacity(0.65), lineWidth: 1)
            )
    }
}

// MARK: - 毛筆進度條

/// 筆觸感進度條：墨色填充、起端略尖、完成端一點朱砂。
struct InkProgressBar: View {
    let progress: Double
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * min(max(progress, 0), 1), 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NNColor.progressTrack)
                    .frame(height: height)

                if progress > 0 {
                    // 筆觸：左端漸細的墨色填充
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [NNColor.progressFill.opacity(0.55),
                                         NNColor.progressFill],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: height)

                    // 完成端朱砂墨點
                    if progress > 0.02 {
                        Circle()
                            .fill(NNColor.accent)
                            .frame(width: height + 2, height: height + 2)
                            .offset(x: width - (height + 2) / 2)
                    }
                }
            }
        }
        .frame(height: height + 2)
    }
}

// MARK: - 墨波聲紋

/// TTS 播放中的墨色波紋：5 根豎條相位錯開呼吸。靜止時齊平。
struct InkWaveform: View {
    var isAnimating: Bool
    var color: Color = NNColor.accent
    var barWidth: CGFloat = 2.5
    var maxHeight: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    private let scales: [CGFloat] = [0.45, 0.8, 1.0, 0.65, 0.5]

    var body: some View {
        HStack(spacing: barWidth * 0.9) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(
                        width: barWidth,
                        height: maxHeight * (animated
                            ? (phase ? scales[i] : scales[(i + 2) % 5])
                            : 0.55)
                    )
                    .animation(
                        animated
                            ? .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.1)
                            : .default,
                        value: phase
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear { if animated { phase = true } }
        .onChange(of: isAnimating) { _, nowPlaying in
            phase = nowPlaying && !reduceMotion
        }
        .accessibilityHidden(true)
    }

    private var animated: Bool { isAnimating && !reduceMotion }
}

// MARK: - Previews

#Preview("Ink Components") {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            SealView(text: "聽")
            SealView(text: "書", size: 48)
            InkWaveform(isAnimating: true)
        }
        InkCoverView(title: "兼職保鏢", palette: NNColor.coverPalettes[0])
            .frame(width: 160, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        InkProgressBar(progress: 0.62)
            .padding(.horizontal)
        Button("墨暈按壓") {}
            .padding()
            .buttonStyle(InkButtonStyle())
    }
    .padding()
    .background(NNColor.appBackground)
    .inkPaper()
}
