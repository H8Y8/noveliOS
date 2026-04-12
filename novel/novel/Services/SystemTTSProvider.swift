import Foundation
import AVFoundation

/// 系統內建 TTS 引擎：包裝 AVSpeechSynthesizer，支援離線使用
/// 使用批次排入機制（每次最多 batchSize 段），避免大量 speak() 呼叫阻塞主執行緒
final class SystemTTSProvider: NSObject, TTSProvider {
    let id = "system"
    let name = "系統語音"
    let requiresNetwork = false
    let handlesPlaybackDirectly = true

    private let synthesizer = AVSpeechSynthesizer()

    /// 每批排入的段落數上限
    private let batchSize = 10

    /// 追蹤佇列中各段落對應的 utterance（供 delegate 識別段落索引）
    /// 使用 NSLock 保護，因為 delegate 回調在任意執行緒
    private let utteranceLock = NSLock()
    private var _queuedUtterances: [(paragraphIndex: Int, utterance: AVSpeechUtterance)] = []
    private var queuedUtterances: [(paragraphIndex: Int, utterance: AVSpeechUtterance)] {
        get { utteranceLock.withLock { _queuedUtterances } }
        set { utteranceLock.withLock { _queuedUtterances = newValue } }
    }

    /// 待排入的段落資料（用於批次追加）
    private var pendingParagraphs: [String] = []
    private var nextPendingIndex: Int = 0
    private var currentVoice: AVSpeechSynthesisVoice?
    private var currentRate: Float = 0.5

    /// 段落開始朗讀時回調，傳入段落索引（供 TTSService 更新高亮）
    var onParagraphStarted: ((Int) -> Void)?

    /// 所有段落朗讀完畢時回調（供 TTSService 觸發章節結束）
    var onAllFinished: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 直接播放 API

    /// 批量排入段落朗讀佇列，從 startAt 開始，每次最多排入 batchSize 段
    func loadParagraphs(_ paragraphs: [String], startAt: Int, voice: TTSVoice, rate: Float) {
        synthesizer.stopSpeaking(at: .immediate)
        queuedUtterances.removeAll()

        let avVoice: AVSpeechSynthesisVoice? = voice.id.isEmpty
            ? AVSpeechSynthesisVoice(language: "zh-TW")
            : AVSpeechSynthesisVoice(identifier: voice.id)

        // 儲存批次參數，供後續追加使用
        pendingParagraphs = paragraphs
        nextPendingIndex = startAt
        currentVoice = avVoice
        currentRate = rate

        // 排入第一批
        enqueueNextBatch()

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
        pendingParagraphs = []
        nextPendingIndex = 0
    }

    // MARK: - 批次排入

    /// 從 pendingParagraphs 排入下一批段落到 AVSpeechSynthesizer
    private func enqueueNextBatch() {
        var enqueued = 0
        while nextPendingIndex < pendingParagraphs.count, enqueued < batchSize {
            let index = nextPendingIndex
            nextPendingIndex += 1

            let trimmed = pendingParagraphs[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let utterance = AVSpeechUtterance(string: trimmed)
            utterance.voice = currentVoice
            utterance.rate = currentRate
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0
            queuedUtterances.append((paragraphIndex: index, utterance: utterance))
            synthesizer.speak(utterance)
            enqueued += 1
        }
    }

    /// 是否還有待排入的段落
    private var hasPendingParagraphs: Bool {
        nextPendingIndex < pendingParagraphs.count
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
        let queued = queuedUtterances
        let isLastInBatch = utterance === queued.last?.utterance

        if isLastInBatch {
            if hasPendingParagraphs {
                // 當前批次播完，追加下一批（在主執行緒排入，確保 UI 不卡頓）
                Task { @MainActor in
                    self.enqueueNextBatch()
                }
            } else {
                // 所有段落播完
                Task { @MainActor in
                    self.onAllFinished?()
                }
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // 取消時不做額外處理，由控制方法管理狀態
    }
}
