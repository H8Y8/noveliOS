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

    // TTS 多引擎設定
    var ttsProvider: String = "system"
    var edgeTTSServerURL: String?
    var edgeTTSVoice: String = "zh-TW-HsiaoChenNeural"
    var azureSubscriptionKey: String?
    var azureRegion: String = "eastasia"
    var azureTTSVoice: String = "zh-TW-HsiaoChenNeural"

    init() {}

    var readingTheme: ReadingTheme {
        get { ReadingTheme(rawValue: theme) ?? .light }
        set { theme = newValue.rawValue }
    }

    var ttsProviderType: TTSProviderType {
        get { TTSProviderType(rawValue: ttsProvider) ?? .system }
        set { ttsProvider = newValue.rawValue }
    }

    var readingMode: ReadingMode {
        get { ReadingMode(rawValue: pageMode) ?? .scroll }
        set { pageMode = newValue.rawValue }
    }
}
