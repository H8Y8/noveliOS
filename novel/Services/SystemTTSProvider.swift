import Foundation
import AVFoundation

/// 系統內建 TTS 引擎：包裝 AVSpeechSynthesizer，支援離線使用
final class SystemTTSProvider: NSObject, TTSProvider {
    let id = "system"
    let name = "系統語音"
    let requiresNetwork = false
    let handlesPlaybackDirectly = true

    private let synthesizer = AVSpeechSynthesizer()

    /// 追蹤佇列中各段落對應的 utterance（供 delegate 識別段落索引）
    private var queuedUtterances: [(paragraphIndex: Int, utterance: AVSpeechUtterance)] = []

    /// 段落開始朗讀時回調，傳入段落索引（供 TTSService 更新高亮）
    var onParagraphStarted: ((Int) -> Void)?

    /// 所有段落朗讀完畢時回調（供 TTSService 觸發章節結束）
    var onAllFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 直接播放 API

    /// 批量排入段落朗讀佇列，從 startAt 到章節末尾，消除段落間停頓
    func loadParagraphs(_ paragraphs: [String], startAt: Int, voice: TTSVoice, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        queuedUtterances.removeAll()

        let avVoice: AVSpeechSynthesisVoice? = voice.id.isEmpty
            ? AVSpeechSynthesisVoice(language: "zh-TW")
            : AVSpeechSynthesisVoice(identifier: voice.id)

        for index in startAt..<paragraphs.count {
            let trimmed = paragraphs[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = avVoice
            utterance.rate = rate
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0
            queuedUtterances.append((paragraphIndex: index, utterance: utterance))
            synthesizer.speak(utterance)
        }

        // 若全為空段落，直接觸發完成
        if queuedUtterances.isEmpty {
            Task { @MainActor in self.onAllFinished?() }
        }
    }

    /// 暫停朗讀
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
    }

    /// 恢復朗讀
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }

    /// 停止朗讀並清空佇列
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        queuedUtterances.removeAll()
    }

    // MARK: - TTSProvider Protocol

    func synthesize(text: String, voice: TTSVoice, rate: Float) async throws -> Data {
        return Data()
    }

    func availableVoices() async throws -> [TTSVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh-TW") }
            .sorted { $0.name < $1.name }
            .map { TTSVoice(id: $0.identifier, name: $0.name, language: $0.language, providerID: id) }
    }

    func isAvailable() async -> Bool {
        true
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SystemTTSProvider: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let entry = queuedUtterances.first(where: { $0.utterance === utterance }) else { return }
        let index = entry.paragraphIndex
        Task { @MainActor in
            self.onParagraphStarted?(index)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard utterance === queuedUtterances.last?.utterance else { return }
        Task { @MainActor in
            self.onAllFinished?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // 取消時不做額外處理，由控制方法管理狀態
    }
}
