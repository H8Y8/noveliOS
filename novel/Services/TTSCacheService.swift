import Foundation

/// 管理每段落 MP3 音訊快取：Caches/tts_audio/{bookId}/{paragraphIndex}.mp3
final class TTSCacheService {

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
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: fileURL(bookId: bookId, index: index))
    }

    func clearCache(for bookId: UUID) {
        try? fileManager.removeItem(at: cacheDirectory(for: bookId))
    }
}
