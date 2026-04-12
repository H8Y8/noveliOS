import Foundation
import AVFoundation

/// TTS 說書服務：多引擎架構的編排器
/// 公開 API 保持不變，內部委派給 TTSProvider 實作
@MainActor
@Observable
class TTSService {
    // MARK: - 公開狀態
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var currentParagraphIndex: Int = 0

    /// 當前書籍 ID（用於追蹤哪本書正在播放）
    var currentBookId: UUID?

    /// 是否已載入段落內容
    var hasContent: Bool {
        !paragraphs.isEmpty
    }

    /// 當前正在朗讀的段落文字（用於迷你播放條預覽）
    var currentParagraphText: String {
        guard currentParagraphIndex >= 0, currentParagraphIndex < paragraphs.count else { return "" }
        return paragraphs[currentParagraphIndex]
    }

    /// 睡眠定時器結束時間
    var sleepTimerEndDate: Date?
    private var sleepTimerTask: Task<Void, Never>?

    // MARK: - 回調
    var onChapterFinished: (() -> Void)?

    // MARK: - 引擎管理
    private(set) var activeProviderType: TTSProviderType = .system

    /// 具體 Provider 實例
    let edgeProvider = EdgeTTSProvider()
    let systemProvider = SystemTTSProvider()
    let azureProvider = AzureTTSProvider()

    /// MP3 音訊播放器（用於 Edge TTS / Azure 等回傳 Data 的引擎）
    private let audioPlayer = AudioPlayerService()

    // MARK: - 私有狀態
    private var paragraphs: [String] = []
    private var rate: Float = 0.5
    private var currentVoice: TTSVoice?
    private var currentSynthesisTask: Task<Void, Never>?
    private var consecutiveFailures: Int = 0

    /// 預取快取：段落索引 → 已合成的音訊資料（記憶體層）
    private var prefetchCache: [Int: Data] = [:]
    /// 背景預取任務
    private var prefetchTask: Task<Void, Never>?
    /// 磁碟層快取（跨 session 持久化）
    private let ttsCache = TTSCacheService()

    /// 中斷通知 observer token（TTSService 為 app 級單例，生命週期與 app 相同，無需 deinit 清理）
    private var interruptionObserver: (any NSObjectProtocol)?
    /// 播放世代計數器（防止過期 callback 推進段落）
    private var playbackGeneration: Int = 0
    /// 當前正在播放的音訊對應的世代
    private var activePlaybackGeneration: Int = 0

    init() {
        // 系統語音：段落開始時更新高亮索引
        systemProvider.onParagraphStarted = { [weak self] index in
            self?.currentParagraphIndex = index
        }
        // 系統語音：所有段落播完 → 章節結束
        systemProvider.onAllFinished = { [weak self] in
            guard let self, self.isPlaying else { return }
            self.isPlaying = false
            self.isPaused = false
            self.onChapterFinished?()
        }
        // Edge / Azure 音訊播完 → 前進到下一段
        audioPlayer.onPlaybackFinished = { [weak self] in
            self?.handleUtteranceFinished()
        }

        // 音訊中斷處理（來電、鬧鐘等）
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor in
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        do {
                            try AVAudioSession.sharedInstance().setActive(true)
                        } catch {
                            #if DEBUG
                            print("⚠️ 音頻會話恢復失敗：\(error.localizedDescription)")
                            #endif
                        }
                        self.play()
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - 睡眠定時器

    /// 設定睡眠定時器（分鐘數），nil 表示取消
    func setSleepTimer(minutes: Int?) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil

        guard let minutes else {
            sleepTimerEndDate = nil
            return
        }

        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndDate = endDate

        sleepTimerTask = Task {
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            stop()
            sleepTimerEndDate = nil
        }
    }

    // MARK: - 引擎設定

    /// 切換 TTS 引擎
    func setProviderType(_ type: TTSProviderType) {
        let wasPlaying = isPlaying
        stop()
        activeProviderType = type
        consecutiveFailures = 0
        if wasPlaying {
            play()
        }
    }

    /// 設定 Edge TTS 伺服器 URL
    func setEdgeServerURL(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty else {
            edgeProvider.serverURLs = []
            return
        }
        // Support comma or newline separated URLs
        let urls = urlString
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { URL(string: $0) }
        edgeProvider.serverURLs = urls
    }

    /// 設定 Azure TTS 憑證
    func setAzureCredentials(key: String?, region: String) {
        azureProvider.subscriptionKey = key
        azureProvider.region = region
    }

    // MARK: - 公開 API（簽章不變）

    /// 載入章節的段落內容
    func loadChapter(paragraphs: [String], startAt: Int = 0) {
        stop()
        self.paragraphs = paragraphs
        self.currentParagraphIndex = startAt
        clearPrefetchCache()
    }

    /// 開始或恢復朗讀
    func play() {
        if isPaused {
            resumePlayback()
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
        pausePlayback()
        isPaused = true
        isPlaying = false
    }

    /// 停止朗讀
    func stop() {
        playbackGeneration += 1
        currentSynthesisTask?.cancel()
        currentSynthesisTask = nil
        stopPlayback()
        isPlaying = false
        isPaused = false
        clearPrefetchCache()
    }

    /// 朗讀下一段
    func nextParagraph() {
        playbackGeneration += 1
        guard currentParagraphIndex < paragraphs.count - 1 else {
            stop()
            onChapterFinished?()
            return
        }
        stopPlayback()
        currentSynthesisTask?.cancel()
        currentParagraphIndex += 1
        isPaused = false
        isPlaying = true
        speakCurrentParagraph()
    }

    /// 朗讀上一段
    func previousParagraph() {
        playbackGeneration += 1
        guard currentParagraphIndex > 0 else { return }
        stopPlayback()
        currentSynthesisTask?.cancel()
        currentParagraphIndex -= 1
        isPaused = false
        isPlaying = true
        speakCurrentParagraph()
    }

    /// 設定語速
    func setRate(_ newRate: Float) {
        playbackGeneration += 1
        rate = newRate
        if isPlaying {
            stopPlayback()
            currentSynthesisTask?.cancel()
            clearPrefetchCache()
            speakCurrentParagraph()
        }
    }

    /// 設定語音（TTSVoice）
    func setVoice(_ voice: TTSVoice?) {
        currentVoice = voice
        clearPrefetchCache()
    }

    /// 設定語音（向下相容：以 AVSpeechSynthesisVoice identifier 設定）
    func setVoice(identifier: String?) {
        if let identifier, !identifier.isEmpty {
            currentVoice = TTSVoice(id: identifier, name: "", language: "zh-TW", providerID: "system")
        } else {
            currentVoice = nil
        }
    }

    /// 跳轉到指定段落
    func seekTo(paragraphIndex: Int) {
        playbackGeneration += 1
        guard paragraphIndex >= 0, paragraphIndex < paragraphs.count else { return }
        let wasPlaying = isPlaying
        stopPlayback()
        currentSynthesisTask?.cancel()
        currentParagraphIndex = paragraphIndex
        if wasPlaying {
            isPaused = false
            isPlaying = true
            speakCurrentParagraph()
        }
    }

    // MARK: - 私有：播放編排

    private func speakCurrentParagraph() {
        guard currentParagraphIndex < paragraphs.count else {
            isPlaying = false
            isPaused = false
            onChapterFinished?()
            return
        }

        let voice = currentVoice ?? defaultVoiceForProvider()

        if activeProviderType == .system {
            // 系統語音：批量排入所有剩餘段落，讓 AVSpeechSynthesizer 無縫銜接
            systemProvider.loadParagraphs(paragraphs, startAt: currentParagraphIndex, voice: voice, rate: rate)
        } else {
            // Edge TTS / Azure：優先使用預取快取，快取命中時可立即播放
            let index = currentParagraphIndex
            let text = paragraphs[index]
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                activePlaybackGeneration = playbackGeneration
                handleUtteranceFinished()
                return
            }

            // Edge/Azure 無法合成純標點文字（如「……」「——」），自動跳過
            let hasSpokenContent = text.unicodeScalars.contains {
                CharacterSet.letters.union(.decimalDigits).contains($0)
            }
            if !hasSpokenContent {
                activePlaybackGeneration = playbackGeneration
                handleUtteranceFinished()
                return
            }

            let provider = activeProvider
            currentSynthesisTask = Task {
                do {
                    let data: Data
                    if let cached = prefetchCache[index] {
                        // 層 1：記憶體預取快取（最快）
                        data = cached
                        prefetchCache.removeValue(forKey: index)
                    } else if let bookId = currentBookId,
                              let fileData = ttsCache.load(bookId: bookId, index: index) {
                        // 層 2：磁碟檔案快取（跨 session，免網路）
                        data = fileData
                    } else {
                        // 層 3：即時網路合成，成功後存入磁碟
                        data = try await provider.synthesize(text: text, voice: voice, rate: rate)
                        if let bookId = currentBookId {
                            ttsCache.save(data: data, bookId: bookId, index: index)
                        }
                    }
                    guard !Task.isCancelled else { return }
                    self.activePlaybackGeneration = self.playbackGeneration
                    try audioPlayer.play(data: data)
                    consecutiveFailures = 0
                    // 播放開始後立即預取接下來 2 段
                    prefetchAhead(from: index, provider: provider, voice: voice)
                } catch {
                    guard !Task.isCancelled else { return }
                    consecutiveFailures += 1
                    #if DEBUG
                    print("[\(activeProviderType.displayName)] 合成失敗（第 \(consecutiveFailures) 次）：\(error.localizedDescription)")
                    #endif

                    if consecutiveFailures >= 3 {
                        #if DEBUG
                        print("連續失敗 \(consecutiveFailures) 次，自動切換至系統語音")
                        #endif
                    }

                    // 降級到系統語音：更新 activeProviderType 確保暫停/恢復控制正確
                    activeProviderType = .system
                    audioPlayer.stop()

                    // 用系統語音朗讀當前段落起的所有剩餘段落
                    let fallbackVoice = TTSVoice(id: "", name: "預設", language: "zh-TW", providerID: "system")
                    systemProvider.loadParagraphs(self.paragraphs, startAt: self.currentParagraphIndex,
                                                  voice: fallbackVoice, rate: self.rate)
                }
            }
        }
    }

    /// 預取 from 之後的 lookaheadCount 段
    /// 優先從磁碟快取載入（免網路），否則合成並同步存入磁碟
    private func prefetchAhead(from index: Int, provider: any TTSProvider, voice: TTSVoice, lookaheadCount: Int = 5) {
        prefetchTask?.cancel()
        prefetchTask = Task {
            for offset in 1...lookaheadCount {
                let nextIndex = index + offset
                guard nextIndex < paragraphs.count else { break }
                guard prefetchCache[nextIndex] == nil else { continue }
                let text = paragraphs[nextIndex]
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                // 跳過純標點文字（Edge/Azure 無法合成）
                guard text.unicodeScalars.contains(where: { CharacterSet.letters.union(.decimalDigits).contains($0) }) else { continue }
                guard !Task.isCancelled else { return }

                // 磁碟有快取：直接讀入記憶體，跳過網路
                if let bookId = currentBookId,
                   let fileData = ttsCache.load(bookId: bookId, index: nextIndex) {
                    prefetchCache[nextIndex] = fileData
                    continue
                }

                // 磁碟無快取：合成並同時存入磁碟（供下次 session 使用）
                do {
                    let data = try await provider.synthesize(text: text, voice: voice, rate: rate)
                    guard !Task.isCancelled else { return }
                    if let bookId = currentBookId {
                        ttsCache.save(data: data, bookId: bookId, index: nextIndex)
                    }
                    prefetchCache[nextIndex] = data
                } catch {
                    #if DEBUG
                    print("⚠️ 預取合成失敗（段落 \(nextIndex)）：\(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    private func clearPrefetchCache() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchCache.removeAll()
    }

    /// 取得當前引擎實例
    private var activeProvider: any TTSProvider {
        switch activeProviderType {
        case .edge: edgeProvider
        case .system: systemProvider
        case .azure: azureProvider
        }
    }

    /// 取得引擎的預設語音
    private func defaultVoiceForProvider() -> TTSVoice {
        switch activeProviderType {
        case .edge:
            TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "曉辰", language: "zh-TW", providerID: "edge")
        case .system:
            TTSVoice(id: "", name: "預設", language: "zh-TW", providerID: "system")
        case .azure:
            TTSVoice(id: "zh-TW-HsiaoChenNeural", name: "曉辰", language: "zh-TW", providerID: "azure")
        }
    }

    // MARK: - 私有：播放控制

    private func pausePlayback() {
        // 同時暫停兩者，確保降級場景下也能正確暫停
        systemProvider.pauseSpeaking()
        audioPlayer.pause()
    }

    private func resumePlayback() {
        if activeProviderType == .system {
            systemProvider.continueSpeaking()
        } else {
            audioPlayer.resume()
        }
    }

    private func stopPlayback() {
        systemProvider.stopSpeaking()
        audioPlayer.stop()
    }

    // MARK: - 私有：段落完成處理

    private func handleUtteranceFinished() {
        guard activePlaybackGeneration == playbackGeneration else { return }
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
