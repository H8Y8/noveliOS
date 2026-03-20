import Foundation

/// Edge TTS 引擎錯誤類型
enum EdgeTTSError: LocalizedError {
    case serverNotConfigured
    case invalidResponse(statusCode: Int)
    case noData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .serverNotConfigured: "Edge TTS 伺服器未設定"
        case .invalidResponse(let code): "伺服器回應錯誤：\(code)"
        case .noData: "未收到音訊資料"
        case .networkError(let error): "網路錯誤：\(error.localizedDescription)"
        }
    }
}

/// Edge TTS 引擎：透過自架 Docker server 的 OpenAI 相容 API 合成語音
final class EdgeTTSProvider: TTSProvider {
    let id = "edge"
    let name = "Edge TTS"
    let requiresNetwork = true
    let handlesPlaybackDirectly = false

    /// Edge TTS server 的基礎 URL，如 http://192.168.1.100:5050
    var serverURL: URL?

    // MARK: - TTSProvider Protocol

    func synthesize(text: String, voice: TTSVoice, rate: Float) async throws -> Data {
        guard let baseURL = serverURL else {
            throw EdgeTTSError.serverNotConfigured
        }

        let endpoint = baseURL.appendingPathComponent("v1/audio/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "tts-1",
            "voice": voice.id,
            "input": text,
            "speed": mapRate(rate)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let maxRetries = 3
        let delays: [Double] = [1.0, 2.0, 4.0]
        var lastError: Error = EdgeTTSError.noData

        for attempt in 0...maxRetries {
            do {
                let (data, response): (Data, URLResponse)
                do {
                    (data, response) = try await URLSession.shared.data(for: request)
                } catch {
                    throw EdgeTTSError.networkError(error)
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EdgeTTSError.noData
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw EdgeTTSError.invalidResponse(statusCode: httpResponse.statusCode)
                }
                guard !data.isEmpty else {
                    throw EdgeTTSError.noData
                }

                return data
            } catch let error as EdgeTTSError {
                switch error {
                case .serverNotConfigured, .invalidResponse:
                    // 不重試
                    throw error
                case .networkError, .noData:
                    lastError = error
                    if attempt < maxRetries {
                        print("[EdgeTTS] 第 \(attempt + 1) 次失敗，\(delays[attempt])s 後重試：\(error.localizedDescription)")
                        try? await Task.sleep(for: .seconds(delays[attempt]))
                    }
                }
            } catch {
                lastError = error
                if attempt < maxRetries {
                    print("[EdgeTTS] 第 \(attempt + 1) 次失敗，\(delays[attempt])s 後重試：\(error.localizedDescription)")
                    try? await Task.sleep(for: .seconds(delays[attempt]))
                }
            }
        }

        throw lastError
    }

    func availableVoices() async throws -> [TTSVoice] {
        // Edge TTS zh-TW 語音靜態列表（微軟 Neural 語音）
        [
            TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "曉辰 (女)", language: "zh-TW", providerID: id),
            TTSVoice(id: "zh-TW-HsiaoYuNeural", name: "曉語 (女)", language: "zh-TW", providerID: id),
            TTSVoice(id: "zh-TW-YunJheNeural", name: "雲哲 (男)", language: "zh-TW", providerID: id),
        ]
    }

    func isAvailable() async -> Bool {
        guard let baseURL = serverURL else { return false }

        // 透過 /v1/models 端點做快速健康檢查
        let healthURL = baseURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private

    /// 將 AVSpeech 語速 (0.3-0.7) 映射到 Edge TTS 速度 (0.5-2.0)
    private func mapRate(_ avspeechRate: Float) -> Float {
        // AVSpeech: 0.3 (慢) - 0.5 (正常) - 0.7 (快)
        // Edge TTS: 0.5 (慢) - 1.0 (正常) - 2.0 (快)
        let normalized = (avspeechRate - 0.3) / 0.4  // 0.0 到 1.0
        return 0.5 + normalized * 1.5                 // 0.5 到 2.0
    }
}
