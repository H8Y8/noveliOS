import SwiftUI

enum ReadingTheme: String, CaseIterable, Identifiable {
    case light
    case sepia
    case gray
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "明亮"
        case .sepia: "護眼"
        case .gray: "灰色"
        case .dark: "夜間"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: Color.white
        case .sepia: Color(red: 0.98, green: 0.95, blue: 0.87)
        case .gray: Color(red: 0.9, green: 0.9, blue: 0.9)
        case .dark: Color.black
        }
    }

    var textColor: Color {
        switch self {
        case .light: Color.black
        case .sepia: Color(red: 0.3, green: 0.25, blue: 0.15)
        case .gray: Color(red: 0.2, green: 0.2, blue: 0.2)
        case .dark: Color.white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: Color.gray
        case .sepia: Color(red: 0.5, green: 0.45, blue: 0.35)
        case .gray: Color(red: 0.4, green: 0.4, blue: 0.4)
        case .dark: Color.gray
        }
    }

    var highlightColor: Color {
        switch self {
        case .light: Color.yellow.opacity(0.3)
        case .sepia: Color.orange.opacity(0.2)
        case .gray: Color.blue.opacity(0.15)
        case .dark: Color.yellow.opacity(0.2)
        }
    }

    var previewColor: Color {
        switch self {
        case .light: Color.white
        case .sepia: Color(red: 0.98, green: 0.95, blue: 0.87)
        case .gray: Color(red: 0.9, green: 0.9, blue: 0.9)
        case .dark: Color.black
        }
    }

    var toolbarStyle: Material {
        switch self {
        case .dark: .ultraThinMaterial
        default: .regularMaterial
        }
    }

    var isDark: Bool {
        self == .dark
    }
}
