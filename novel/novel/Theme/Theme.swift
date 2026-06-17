import SwiftUI
import UIKit

// MARK: - NovelNarrator Design System「墨韻」
// 設計原則：閱讀優先、暗色系為主、中國水墨美學——墨分五色、朱砂一點
// 墨色皆偏暖灰（宣紙米調），朱砂僅作小面積點綴（<5%：播放鍵、印章、選中態）
// 禁止：大面積紅/金、Tab Bar、FAB、圓角超過 16pt 的卡片、第三方動畫庫

// MARK: - Brand Colors
// 用於書庫、非閱讀場景的全局品牌色彩。
// 點綴色：朱砂印泥紅（去飽和，呼應書畫印章，非正紅）

enum NNColor {

    // MARK: Adaptive Helper

    /// 根據 Light / Dark 模式自動切換的自適應色彩
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    // MARK: Brand

    /// 點綴色：朱砂印泥紅（Dark 模式微亮以維持對比）
    static let accent      = adaptive(light: "#A63A2E", dark: "#C04A3C")
    /// 強調色亮版（hover / 選中態）
    static let accentLight = Color(hex: "#C04A3C")
    /// 強調色暗版（pressed 態）
    static let accentDark  = Color(hex: "#7E2B22")

    // MARK: Library Surface（書庫介面，支援 Light / Dark）

    /// App 全局底色（Light: 宣紙米 / Dark: 夜宣黑）
    static let appBackground    = adaptive(light: "#F4EFE6", dark: "#121210")
    /// 書卡背景
    static let cardBackground   = adaptive(light: "#FBF7EE", dark: "#1C1C19")
    /// 卡片 hover / 選中
    static let cardHighlight    = adaptive(light: "#EFE8DA", dark: "#26261F")
    /// 分隔線
    static let separator        = adaptive(light: "#DDD5C4", dark: "#2A2A26")

    // MARK: Text（書庫文字，支援 Light / Dark）— 濃墨/重墨/淡墨三階

    static let textPrimary      = adaptive(light: "#2B2B26", dark: "#D6D4CC")
    static let textSecondary    = adaptive(light: "#6E6E64", dark: "#8A8A82")
    static let textTertiary     = adaptive(light: "#A8A498", dark: "#55554E")

    // MARK: Status

    /// 進行中（TTS 播放聲波）— 墨色
    static let playing          = adaptive(light: "#4A4A45", dark: "#B0AEA4")
    /// 進度條填充 — 墨色（完成端朱砂點由 InkProgressBar 處理）
    static let progressFill     = adaptive(light: "#4A4A45", dark: "#B0AEA4")
    /// 進度條軌道
    static let progressTrack    = adaptive(light: "#DDD5C4", dark: "#2A2A26")

    // MARK: Book Cover Palettes（遠山墨色，8 組漸層）
    // 使用書名 hash % 8 選色組，配合 InkCoverView 畫遠山剪影

    static let coverPalettes: [(Color, Color)] = [
        (Color(hex: "#2A3438"), Color(hex: "#46565C")),  // 墨青
        (Color(hex: "#252C3A"), Color(hex: "#3E4A60")),  // 黛藍
        (Color(hex: "#352A22"), Color(hex: "#54453A")),  // 赭墨
        (Color(hex: "#2E2A20"), Color(hex: "#4A4434")),  // 茶墨
        (Color(hex: "#2C2C28"), Color(hex: "#4A4A44")),  // 灰墨
        (Color(hex: "#243430"), Color(hex: "#3C544E")),  // 青碧
        (Color(hex: "#2E2832"), Color(hex: "#4A4252")),  // 紫墨
        (Color(hex: "#262420"), Color(hex: "#403C34")),  // 焦墨
    ]
}

// MARK: - Typography

enum NNFont {

    // MARK: Reading Font Families（閱讀字體）

    enum ReadingFamily: String, CaseIterable, Identifiable {
        case system   = "System"
        case pingFang = "PingFang TC"
        case notoSans = "Noto Sans TC"
        case songti   = "Songti TC"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .songti: "宋體"
            default:      rawValue
            }
        }

        func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            switch self {
            case .system:
                return .system(size: size, weight: weight, design: .default)
            case .pingFang:
                return .custom("PingFangTC-Regular", size: size)
            case .notoSans:
                return .custom("NotoSansTC-Regular", size: size)
            case .songti:
                return .custom("STSongti-TC-Regular", size: size)
            }
        }
    }

    // MARK: Ink Title（水墨標題字型）

    /// 水墨標題字型（宋體，iOS 內建），用於畫面標題/書名/章節名/主題名。
    /// 字型缺失時退回系統 serif。
    static func inkTitle(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let name = (weight == .bold || weight == .semibold)
            ? "STSongti-TC-Bold" : "STSongti-TC-Regular"
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Reading Scale（閱讀排版）

    /// 閱讀主文字體（字級 14–32pt，由 UserSettings.fontSize 控制）
    static func readerBody(size: CGFloat, family: ReadingFamily = .system) -> Font {
        family.font(size: size)
    }

    // MARK: UI Scale（介面文字，固定字號）

    static let uiLargeTitle  = Font.system(size: 28, weight: .bold,      design: .default)
    static let uiTitle       = Font.system(size: 20, weight: .semibold,  design: .default)
    static let uiHeadline    = Font.system(size: 17, weight: .semibold,  design: .default)
    static let uiBody        = Font.system(size: 15, weight: .regular,   design: .default)
    static let uiSubheadline = Font.system(size: 14, weight: .regular,   design: .default)
    static let uiCaption     = Font.system(size: 12, weight: .regular,   design: .default)
    static let uiCaption2    = Font.system(size: 11, weight: .regular,   design: .default)

    // MARK: Line Spacing（行距乘數，對應 UserSettings.lineSpacing）

    enum LineSpacing: Double, CaseIterable, Identifiable {
        case compact = 1.2
        case normal  = 1.5
        case relaxed = 1.8
        case loose   = 2.0

        var id: Double { rawValue }

        var displayName: String {
            switch self {
            case .compact: "緊湊"
            case .normal:  "標準"
            case .relaxed: "寬鬆"
            case .loose:   "最寬"
            }
        }

        /// 換算成 SwiftUI lineSpacing 的點數（基準字號 18pt）
        func points(for fontSize: CGFloat) -> CGFloat {
            fontSize * (rawValue - 1.0)
        }
    }
}

// MARK: - Spacing

enum NNSpacing {
    static let xxs: CGFloat =  2
    static let xs:  CGFloat =  4
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48

    // MARK: Reading Layout

    /// 閱讀器左右安全邊距（6.7 吋單手操作，拇指不遮字）
    static let readerHorizontal: CGFloat = 20
    /// 閱讀器段落間距
    static let readerParagraphSpacing: CGFloat = 12

    // MARK: Card

    /// 書庫卡片圓角（≤16pt，遵循設計規範）
    static let cardCornerRadius: CGFloat = 12
    /// 書庫卡片內邊距
    static let cardPadding: CGFloat = 14
    /// 書庫卡片間距
    static let cardSpacing: CGFloat = 12

    // MARK: Touch Target（符合 HIG 最小 44pt）

    static let minTouchTarget: CGFloat = 44
    /// TTS 主要控制按鈕（比標準大 1.5 倍，方便盲操作）
    static let ttsButtonSize: CGFloat = 52
    /// TTS 次要控制按鈕
    static let ttsSecondaryButtonSize: CGFloat = 40

    // MARK: Toolbar

    static let toolbarHeight: CGFloat = 56
    static let bottomToolbarHeight: CGFloat = 100
}

// MARK: - Animation
// 所有動畫使用 SwiftUI 原生 API，不引入第三方動畫庫

enum NNAnimation {

    /// 工具列顯示/隱藏：fade + slide，0.25s
    static let toolbarToggle  = Animation.easeInOut(duration: 0.25)

    /// TTS 段落高亮切換：easeOut（進入型動畫，0.25s）
    static let ttsHighlight   = Animation.easeOut(duration: 0.25)

    /// Sheet 展開/收合（TTS 播放器、設定）：spring
    static let sheetSpring    = Animation.spring(response: 0.4, dampingFraction: 0.78)

    /// 書庫卡片 onAppear 交錯淡入：每張卡片延遲基數
    static let cardAppearBase = Animation.easeOut(duration: 0.35)
    static func cardAppear(index: Int) -> Animation {
        cardAppearBase.delay(Double(index) * 0.06)
    }

    /// 翻頁動畫（分頁模式）
    static let pageFlip       = Animation.easeInOut(duration: 0.28)

    /// 微互動（按鈕 tap、選項切換）
    static let micro          = Animation.easeInOut(duration: 0.15)

    /// 進度條拖拽反饋
    static let sliderFeedback = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// 進度數值更新
    static let progressUpdate = Animation.easeOut(duration: 0.2)

    /// 側欄滑入
    static let sidebarSlide   = Animation.easeOut(duration: 0.25)

    /// 墨暈按壓擴散
    static let inkSpread      = Animation.easeOut(duration: 0.35)

    /// 書卡墨滴暈開入場（scale + opacity + blur 消散）
    static let inkDropAppear  = Animation.easeOut(duration: 0.45)
    static func inkDrop(index: Int) -> Animation {
        inkDropAppear.delay(Double(index) * 0.06)
    }
}

// MARK: - SF Symbols Reference
// 圖標統一使用 SF Symbols，不引入第三方圖標庫

enum NNSymbol {
    // Navigation
    static let back          = "chevron.left"
    static let chapterList   = "list.bullet"
    static let settings      = "gearshape"

    // TTS Controls（比標準字號大 1.5 倍用於播放器）
    static let play          = "play.fill"
    static let pause         = "pause.fill"
    static let next          = "forward.fill"
    static let previous      = "backward.fill"
    static let speakerWave   = "waveform"
    static let sleepTimer    = "moon.zzz"
    static let speedometer   = "gauge.medium"

    // Library
    static let addBook       = "plus"
    static let importFile    = "square.and.arrow.down"
    static let deleteBook    = "trash"
    static let renameBook    = "pencil"
    static let bookClosed    = "book.closed"
    static let bookOpen      = "book.open"

    // Settings
    static let fontSize      = "textformat.size"
    static let lineHeight    = "text.alignleft"
    static let theme         = "circle.lefthalf.filled"
    static let font          = "character"
    static let scrollMode    = "scroll"
    static let pageMode      = "book"
}

// MARK: - Color Hex Initializer

extension Color {
    /// 從 Hex 字串初始化 Color，支援 #RRGGBB 與 #RRGGBBAA
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
