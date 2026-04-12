import Foundation

/// 管理每段落 MP3 音訊快取：Caches/tts_audio/{bookId}/{paragraphIndex}.mp3
/// @unchecked Sendable：所有方法僅使用 FileManager 進行檔案 I/O，為執行緒安全操作
final class TTSCacheService: @unchecked Sendable {

    private let fileManager = FileManager.default

    // MARK: - Paths

    private func cacheDirectory(for bookId: UUID) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches
            .appendingPathComponent("tts_audio", isDirectory: true)
            .appendingPathComponent(bookId.uuidString, isDirectory: true)
    }

    private func fileURL(bookId: UUID, index: Int) -> URL {
        cacheDirectory(for: bookId).appendingPathComponent("\(index).mp3")
    }

    // MARK: - Read

    func isCached(bookId: UUID, index: Int) -> Bool {
        fileManager.fileExists(atPath: fileURL(bookId: bookId, index: index).path)
    }

    func load(bookId: UUID, index: Int) -> Data? {
        try? Data(contentsOf: fileURL(bookId: bookId, index: index))
    }

    /// 計算已存入的 .mp3 檔案數量
    func synthesizedCount(for bookId: UUID) -> Int {
        let dir = cacheDirectory(for: bookId)
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return 0 }
        return contents.filter { $0.pathExtension == "mp3" }.count
    }

    // MARK: - Write

    func save(data: Data, bookId: UUID, index: Int) {
        let dir = cacheDirectory(for: bookId)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: fileURL(bookId: bookId, index: index))
        } catch {
            #if DEBUG
            print("⚠️ TTS 快取寫入失敗（段落 \(index)）：\(error.localizedDescription)")
            #endif
        }
    }

    func clearCache(for bookId: UUID) {
        try? fileManager.removeItem(at: cacheDirectory(for: bookId))
    }
}
