import Foundation

/// Azure Cognitive Services TTS 引擎
final class AzureTTSProvider: TTSProvider {
    let id = "azure"
    let name = "Azure TTS"
    let requiresNetwork = true
    let handlesPlaybackDirectly = false

    var subscriptionKey: String?
    var region: String = "eastasia"

    func synthesize(text: String, voice: TTSVoice, rate: Float) async throws -> Data {
        guard let key = subscriptionKey, !key.isEmpty, !region.isEmpty else {
            throw AzureTTSError.notConfigured
        }

        let endpointString = "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1"
        guard let url = URL(string: endpointString) else {
            throw AzureTTSError.notConfigured
        }

        let ssmlRate = ssmlRateString(from: rate)
        let voiceName = voice.id.isEmpty ? "zh-TW-HsiaoChenNeural" : voice.id
        let ssml = """
        <speak version='1.0' xml:lang='zh-TW'>\
        <voice xml:lang='zh-TW' name='\(voiceName)'>\
        <prosody rate='\(ssmlRate)'>\(text)</prosody>\
        </voice></speak>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.httpBody = ssml.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AzureTTSError.noData
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw AzureTTSError.httpError(statusCode: httpResponse.statusCode)
            }
            guard !data.isEmpty else {
                throw AzureTTSError.noData
            }
            return data
        } catch let error as AzureTTSError {
            throw error
        } catch {
            throw AzureTTSError.networkError(error)
        }
    }

    func availableVoices() async throws -> [TTSVoice] {
        [
            TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "曉辰 (女)", language: "zh-TW", providerID: id),
            TTSVoice(id: "zh-TW-HsiaoYuNeural", name: "曉語 (女)", language: "zh-TW", providerID: id),
            TTSVoice(id: "zh-TW-YunJheNeural", name: "雲哲 (男)", language: "zh-TW", providerID: id),
        ]
    }

    func isAvailable() async -> Bool {
        guard let key = subscriptionKey, !key.isEmpty, !region.isEmpty else {
            return false
        }
        return true
    }

    // MARK: - 私有：語速轉換

    /// 將 AVSpeech rate (0.3–0.7) 映射到 SSML rate 字串
    /// 0.3 → "-50%", 0.5 → "0%", 0.7 → "+100%"
    private func ssmlRateString(from rate: Float) -> String {
        let clamped = min(max(rate, 0.3), 0.7)
        let percent: Int
        if clamped <= 0.5 {
            // 0.3…0.5 → -50%…0%
            let ratio = (clamped - 0.3) / (0.5 - 0.3)
            percent = Int((-50.0 + ratio * 50.0).rounded())
        } else {
            // 0.5…0.7 → 0%…+100%
            let ratio = (clamped - 0.5) / (0.7 - 0.5)
            percent = Int((ratio * 100.0).rounded())
        }
        if percent > 0 {
            return "+\(percent)%"
        } else {
            return "\(percent)%"
        }
    }
}

enum AzureTTSError: LocalizedError {
    case notConfigured
    case httpError(statusCode: Int)
    case noData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Azure TTS 尚未設定訂閱金鑰或區域"
        case .httpError(let statusCode):
            return "Azure TTS HTTP 錯誤：\(statusCode)"
        case .noData:
            return "Azure TTS 未回傳音訊資料"
        case .networkError(let error):
            return "Azure TTS 網路錯誤：\(error.localizedDescription)"
        }
    }
}
