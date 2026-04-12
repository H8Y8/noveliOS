import Foundation

// MARK: - TTS 語音定義

/// 代表一個 TTS 語音選項
struct TTSVoice: Identifiable, Codable, Hashable, Sendable {
    let id: String          // 語音識別碼，如 "zh-TW-HsiaoChenNeural" 或 AVSpeechSynthesisVoice.identifier
    let name: String        // 顯示名稱，如 "曉辰 (女)"
    let language: String    // 語言代碼，如 "zh-TW"
    let providerID: String  // 所屬引擎，如 "edge", "system", "azure"
}

// MARK: - TTS 引擎類型

/// TTS 語音引擎類型
enum TTSProviderType: String, CaseIterable, Identifiable {
    case edge = "edge"
    case system = "system"
    case azure = "azure"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .edge: "Edge TTS (網路)"
        case .system: "系統語音 (離線)"
        case .azure: "Azure TTS"
        }
    }

    var requiresNetwork: Bool {
        switch self {
        case .edge, .azure: true
        case .system: false
        }
    }
}

// MARK: - TTS Provider Protocol

/// TTS 語音合成引擎的通用協定
protocol TTSProvider: AnyObject {
    /// 引擎識別碼
    var id: String { get }
    /// 引擎顯示名稱
    var name: String { get }
    /// 是否需要網路連線
    var requiresNetwork: Bool { get }
    /// 是否直接處理播放（如 AVSpeechSynthesizer），而非回傳音訊 Data
    var handlesPlaybackDirectly: Bool { get }

    /// 將文字合成為音訊 Data（MP3 或其他格式）
    /// 對於 handlesPlaybackDirectly == true 的引擎，回傳空 Data
    func synthesize(text: String, voice: TTSVoice, rate: Float) async throws -> Data

    /// 取得此引擎可用的語音列表
    func availableVoices() async throws -> [TTSVoice]

    /// 檢查此引擎目前是否可用
    func isAvailable() async -> Bool
}
