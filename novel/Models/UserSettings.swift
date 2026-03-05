import Foundation
import SwiftData
import SwiftUI

@Model
class UserSettings {
    var fontSize: Double = 18.0
    var lineSpacing: Double = 1.5
    var theme: String = "light"
    var fontFamily: String = "System"
    var ttsRate: Float = 0.5
    var ttsVoiceIdentifier: String?
    var pageMode: String = "scroll"

    init() {}

    var readingTheme: ReadingTheme {
        get { ReadingTheme(rawValue: theme) ?? .light }
        set { theme = newValue.rawValue }
    }
}
