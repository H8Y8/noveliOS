import Foundation

/// 全書語音預合成服務
/// 在背景批次呼叫 TTS API，將音訊存入本地快取，支援暫停/繼續（重跑時跳過已快取）
@Observable
final class BookSynthesisService {

    // MARK: - 公開狀態

    var isSynthesizing: Bool = false
    /// 已處理段落數（已快取 + 空段落 + 新合成）
    var synthesizedCount: Int = 0
    /// 全書段落總數
    var totalCount: Int = 0
    /// 非空段落數（需要網路合成的數量）
    var nonEmptyCount: Int = 0

    var progress: Double {
        totalCount > 0 ? Double(synthesizedCount) / Double(totalCount) : 0
    }

    var isComplete: Bool {
        totalCount > 0 && synthesizedCount >= totalCount
    }

    // MARK: - Private

    private let cache = TTSCacheService()
    private var synthesisTask: Task<Void, Never>?

    // MARK: - Public API

    /// 從磁碟讀取已快取數量，更新進度狀態（在 sheet appear 時呼叫）
    func loadStatus(bookId: UUID, paragraphs: [String]) {
        totalCount = paragraphs.count
        let cache = self.cache
        Task.detached(priority: .utility) {
            var cachedCount = 0
            var nonEmpty = 0
            for (index, text) in paragraphs.enumerated() {
                let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if !isEmpty { nonEmpty += 1 }
                if isEmpty || cache.isCached(bookId: bookId, index: index) {
                    cachedCount += 1
                }
            }
            await MainActor.run {
                self.nonEmptyCount = nonEmpty
                self.synthesizedCount = cachedCount
            }
        }
    }

    /// 開始批次合成（已快取的段落自動跳過，支援重入）
    func startSynthesis(
        bookId: UUID,
        paragraphs: [String],
        provider: any TTSProvider,
        voice: TTSVoice,
        rate: Float
    ) {
        guard !isSynthesizing else { return }

        totalCount = paragraphs.count
        nonEmptyCount = paragraphs.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count

        // 計算已完成的段落數，收集待合成的索引
        var preExistingCount = 0
        var pendingIndices: [Int] = []

        for (index, text) in paragraphs.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || cache.isCached(bookId: bookId, index: index) {
                preExistingCount += 1
            } else {
                pendingIndices.append(index)
            }
        }

        synthesizedCount = preExistingCount
        isSynthesizing = true

        synthesisTask = Task {
            // 滑動視窗並發：最多 8 路同時合成（本機 Docker 伺服器可承受）
            await withTaskGroup(of: Void.self) { group in
                var inFlight = 0
                let maxConcurrency = 8

                for index in pendingIndices {
                    if inFlight >= maxConcurrency {
                        await group.next()
                        inFlight -= 1
                    }
                    guard !Task.isCancelled else { break }

                    let text = paragraphs[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    inFlight += 1

                    group.addTask {
                        guard !Task.isCancelled else { return }
                        if let data = try? await provider.synthesize(
                            text: text, voice: voice, rate: rate
                        ) {
                            self.cache.save(data: data, bookId: bookId, index: index)
                        }
                        await MainActor.run { self.synthesizedCount += 1 }
                    }
                }
                // 等待剩餘任務結束
                for await _ in group {}
            }

            await MainActor.run { self.isSynthesizing = false }
        }
    }

    func cancel() {
        synthesisTask?.cancel()
        synthesisTask = nil
        isSynthesizing = false
    }

    func clearCache(bookId: UUID) {
        cancel()
        cache.clearCache(for: bookId)
        synthesizedCount = 0
    }
}
