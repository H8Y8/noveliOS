import SwiftUI

// MARK: - Reading Theme
// 四套閱讀主題，rawValue 與 SwiftData 儲存的字串對應，不可更改。
// 設計規範：暗色系為主，台灣日系簡潔美學，無紅色/金色主色調。

enum ReadingTheme: String, CaseIterable, Identifiable {
    /// 墨夜：OLED 純黑底，柔灰字。省電、最適合暗房。
    case dark  = "dark"
    /// 暖燈：深暖棕底，奶油字。模擬夜燈下閱讀質感。
    case sepia = "sepia"
    /// 紙白：米白底，墨字。仿電子墨水紙，日間首選。
    case light = "light"
    /// 薄霧：深灰底，低對比淺灰字。長時間護眼。
    case gray  = "gray"

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .dark:  "墨夜"
        case .sepia: "暖燈"
        case .light: "紙白"
        case .gray:  "薄霧"
        }
    }

    var displayDescription: String {
        switch self {
        case .dark:  "OLED 省電・暗房首選"
        case .sepia: "暖燈質感・睡前閱讀"
        case .light: "仿紙質感・日間閱讀"
        case .gray:  "低對比・長時間護眼"
        }
    }

    // MARK: Background

    /// 閱讀區域背景色
    var backgroundColor: Color {
        switch self {
        case .dark:  Color(hex: "#000000")               // 純 OLED 黑
        case .sepia: Color(hex: "#1C1410")               // 深暖棕
        case .light: Color(hex: "#F5F0E8")               // 米白紙感
        case .gray:  Color(hex: "#1E1E22")               // 深藍灰
        }
    }

    // MARK: Text

    /// 主要閱讀文字色（非純白，減少刺激）
    var textColor: Color {
        switch self {
        case .dark:  Color(hex: "#D4D4D4")               // 柔灰，非純白
        case .sepia: Color(hex: "#E8D5B0")               // 暖奶油
        case .light: Color(hex: "#1A1A1A")               // 近黑墨
        case .gray:  Color(hex: "#B8B8C0")               // 低飽和淺灰
        }
    }

    /// 次要文字（頁碼、時間戳、工具列標籤）— 皆符合 WCAG AA 4.5:1 對比
    var secondaryTextColor: Color {
        switch self {
        case .dark:  Color(hex: "#787878")               // 4.6:1 on #000000
        case .sepia: Color(hex: "#9A8A72")               // 4.5:1 on #1C1410
        case .light: Color(hex: "#6B6B6B")               // 5.2:1 on #F5F0E8
        case .gray:  Color(hex: "#8585A0")               // 4.6:1 on #1E1E22
        }
    }

    // MARK: TTS Highlight

    /// TTS 朗讀時當前段落的柔和底色，避免螢光色
    var highlightColor: Color {
        switch self {
        case .dark:  Color(hex: "#5B7FA6").opacity(0.22)  // 霧藍
        case .sepia: Color(hex: "#9C7A45").opacity(0.25)  // 暖琥珀
        case .light: Color(hex: "#5B7FA6").opacity(0.12)  // 淡霧藍
        case .gray:  Color(hex: "#7878A0").opacity(0.20)  // 中性藍灰
        }
    }

    // MARK: UI Chrome

    /// 用於主題色塊預覽（SettingsSheet 主題選擇器）
    var previewColor: Color { backgroundColor }

    /// 工具列 Material 模糊效果
    var toolbarStyle: Material {
        switch self {
        case .light: .regularMaterial
        default:     .ultraThinMaterial
        }
    }

    /// 工具列上覆蓋一層漸層，讓文字自然淡入背景
    var toolbarGradient: LinearGradient {
        let color = backgroundColor
        switch self {
        case .light:
            return LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0)],
                startPoint: .bottom, endPoint: .top
            )
        default:
            return LinearGradient(
                colors: [color.opacity(0.98), color.opacity(0)],
                startPoint: .bottom, endPoint: .top
            )
        }
    }

    /// 分隔線 / 邊框色
    var separatorColor: Color {
        switch self {
        case .dark:  Color(hex: "#2A2A2A")
        case .sepia: Color(hex: "#2E2420")
        case .light: Color(hex: "#D8D0C0")
        case .gray:  Color(hex: "#2E2E36")
        }
    }

    var isDark: Bool {
        switch self {
        case .dark, .sepia, .gray: true
        case .light: false
        }
    }
}
