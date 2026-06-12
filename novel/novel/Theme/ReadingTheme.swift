import SwiftUI

// MARK: - Reading Theme「水墨四境」
// 四套閱讀主題，rawValue 與 SwiftData 儲存的字串對應，不可更改。
// 設計規範：暗色系為主，水墨美學——墨色偏暖灰（宣紙調），朱砂僅作極淡點綴。

enum ReadingTheme: String, CaseIterable, Identifiable {
    /// 夜墨：OLED 純黑底，柔墨灰字。省電、最適合暗房。
    case dark  = "dark"
    /// 茶褐：深茶棕底，茶米字。模擬夜燈下閱讀質感。
    case sepia = "sepia"
    /// 宣紙：宣紙米底，濃墨字。仿宣紙質感，日間首選。
    case light = "light"
    /// 黛青：青黛灰底，低對比青灰字。長時間護眼。
    case gray  = "gray"

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .dark:  String(localized: "夜墨")
        case .sepia: String(localized: "茶褐")
        case .light: String(localized: "宣紙")
        case .gray:  String(localized: "黛青")
        }
    }

    var displayDescription: String {
        switch self {
        case .dark:  String(localized: "OLED 省電・暗房首選")
        case .sepia: String(localized: "暖茶質感・睡前閱讀")
        case .light: String(localized: "仿宣紙感・日間閱讀")
        case .gray:  String(localized: "低對比・長時間護眼")
        }
    }

    // MARK: Background

    /// 閱讀區域背景色
    var backgroundColor: Color {
        switch self {
        case .dark:  Color(hex: "#000000")               // 純 OLED 黑
        case .sepia: Color(hex: "#221A10")               // 深茶棕
        case .light: Color(hex: "#F4EFE6")               // 宣紙米
        case .gray:  Color(hex: "#1B1F22")               // 青黛灰
        }
    }

    // MARK: Text

    /// 主要閱讀文字色（非純白，減少刺激）
    var textColor: Color {
        switch self {
        case .dark:  Color(hex: "#D4D2CA")               // 柔墨灰，非純白
        case .sepia: Color(hex: "#E2D2AE")               // 茶米
        case .light: Color(hex: "#2B2B26")               // 濃墨
        case .gray:  Color(hex: "#B4BCC0")               // 低飽和青灰
        }
    }

    /// 次要文字（頁碼、時間戳、工具列標籤）— 皆符合 WCAG AA 4.5:1 對比
    var secondaryTextColor: Color {
        switch self {
        case .dark:  Color(hex: "#7C7A74")               // ≥4.5:1 on #000000
        case .sepia: Color(hex: "#9C8B6E")               // ≥4.5:1 on #221A10
        case .light: Color(hex: "#6E6E64")               // ≥4.5:1 on #F4EFE6
        case .gray:  Color(hex: "#7E8A90")               // ≥4.5:1 on #1B1F22
        }
    }

    // MARK: TTS Highlight

    /// TTS 朗讀時當前段落的柔和底色，避免螢光色
    var highlightColor: Color {
        switch self {
        case .dark:  Color(hex: "#5C7A78").opacity(0.22)  // 墨青暈
        case .sepia: Color(hex: "#9C7A45").opacity(0.25)  // 暖赭暈
        case .light: Color(hex: "#A63A2E").opacity(0.08)  // 極淡朱砂暈
        case .gray:  Color(hex: "#5C7A88").opacity(0.20)  // 青墨暈
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
        case .dark:  Color(hex: "#2A2A26")
        case .sepia: Color(hex: "#322818")
        case .light: Color(hex: "#DDD5C4")
        case .gray:  Color(hex: "#2A3034")
        }
    }

    var isDark: Bool {
        switch self {
        case .dark, .sepia, .gray: true
        case .light: false
        }
    }
}
