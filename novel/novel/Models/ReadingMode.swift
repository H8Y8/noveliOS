import Foundation

/// 閱讀模式：捲動或翻頁
enum ReadingMode: String, CaseIterable, Identifiable {
    /// 上下捲動，連續閱讀
    case scroll = "scroll"
    /// 左右翻頁，仿真書頁捲動效果（類似 Apple Books）
    case pageCurl = "pageCurl"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scroll:   String(localized: "捲動")
        case .pageCurl: String(localized: "翻頁")
        }
    }

    var displayDescription: String {
        switch self {
        case .scroll:   String(localized: "上下滑動・連續閱讀")
        case .pageCurl: String(localized: "左右翻頁・仿真書感")
        }
    }

    var iconName: String {
        switch self {
        case .scroll:   NNSymbol.scrollMode
        case .pageCurl: NNSymbol.pageMode
        }
    }
}
