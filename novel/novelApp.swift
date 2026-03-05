import SwiftUI
import SwiftData
import AVFoundation

@main
struct novelApp: App {
    let ttsService = TTSService()

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(ttsService)
        }
        .modelContainer(for: [Book.self, UserSettings.self])
    }

    /// 設定音頻會話，支援背景播放
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音頻會話設定失敗：\(error)")
        }
    }
}
