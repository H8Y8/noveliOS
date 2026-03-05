import Foundation
import AVFoundation

/// TTS 說書服務：封裝 AVSpeechSynthesizer，提供段落朗讀控制
@Observable
class TTSService: NSObject {
    // MARK: - 公開狀態
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var currentParagraphIndex: Int = 0
    /// 目前載入的書籍 ID，供 LibraryView 顯示播放中指示
    var currentBookId: UUID?
    /// 睡眠計時器到期時間（nil = 關閉）
    var sleepTimerEndDate: Date?

    // MARK: - 回調
    var onChapterFinished: (() -> Void)?

    // MARK: - 私有屬性
    private let synthesizer = AVSpeechSynthesizer()
    private var paragraphs: [String] = []
    private var rate: Float = 0.5
    private var voiceIdentifier: String?

    // MARK: - 衍生狀態

    /// 當前朗讀段落文字，供 NarratorPlayerView 預覽
    var currentParagraphText: String {
        guard currentParagraphIndex < paragraphs.count else { return "" }
        return paragraphs[currentParagraphIndex]
    }

    /// 是否有已載入的段落（用於判斷是否顯示迷你播放條）
    var hasContent: Bool { !paragraphs.isEmpty }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 公開 API

    /// 載入章節的段落內容
    func loadChapter(paragraphs: [String], startAt: Int = 0) {
        stop()
        self.paragraphs = paragraphs
        self.currentParagraphIndex = startAt
    }

    /// 開始或恢復朗讀
    func play() {
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isPlaying = true
            return
        }

        guard !paragraphs.isEmpty else { return }
        isPlaying = true
        isPaused = false
        speakCurrentParagraph()
    }

    /// 暫停朗讀
    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isPlaying = false
    }

    /// 停止朗讀
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
    }

    /// 朗讀下一段
    func nextParagraph() {
        guard currentParagraphIndex < paragraphs.count - 1 else {
            stop()
            onChapterFinished?()
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex += 1
        isPaused = false
        isPlaying = true
        speakCurrentParagraph()
    }

    /// 朗讀上一段
    func previousParagraph() {
        guard currentParagraphIndex > 0 else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex -= 1
        isPaused = false
        isPlaying = true
        speakCurrentParagraph()
    }

    /// 設定語速（暫停後以新速率重新開始當前段落）
    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying {
            synthesizer.stopSpeaking(at: .immediate)
            speakCurrentParagraph()
        }
    }

    /// 設定語音
    func setVoice(identifier: String?) {
        voiceIdentifier = identifier
    }

    /// 設定睡眠計時器（minutes = nil 代表關閉）
    func setSleepTimer(minutes: Int?) {
        if let minutes {
            sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        } else {
            sleepTimerEndDate = nil
        }
    }

    /// 跳轉到指定段落
    func seekTo(paragraphIndex: Int) {
        guard paragraphIndex >= 0, paragraphIndex < paragraphs.count else { return }
        let wasPlaying = isPlaying
        synthesizer.stopSpeaking(at: .immediate)
        currentParagraphIndex = paragraphIndex
        if wasPlaying {
            isPaused = false
            isPlaying = true
            speakCurrentParagraph()
        }
    }

    // MARK: - 私有方法

    private func speakCurrentParagraph() {
        guard currentParagraphIndex < paragraphs.count else {
            isPlaying = false
            isPaused = false
            onChapterFinished?()
            return
        }

        let text = paragraphs[currentParagraphIndex]
        guard !text.isEmpty else {
            // 跳過空段落
            handleUtteranceFinished()
            return
        }

        let utterance = AVSpeechUtterance(string: text)
        if let voiceId = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-TW")
        }
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        synthesizer.speak(utterance)
    }

    fileprivate func handleUtteranceFinished() {
        // 檢查睡眠計時器：到期則自動暫停
        if let endDate = sleepTimerEndDate, Date() >= endDate {
            sleepTimerEndDate = nil
            isPlaying = false
            isPaused = false
            return
        }

        guard isPlaying || (!isPaused && currentParagraphIndex < paragraphs.count - 1) else { return }

        if currentParagraphIndex < paragraphs.count - 1 {
            currentParagraphIndex += 1
            speakCurrentParagraph()
        } else {
            // 章節朗讀完畢
            isPlaying = false
            isPaused = false
            onChapterFinished?()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleUtteranceFinished()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // 取消時不做額外處理，由控制方法管理狀態
    }
}
