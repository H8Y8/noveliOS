import SwiftUI
import SwiftData
import AVFoundation

@main
struct novelApp: App {
    let ttsService = TTSService()
    let modelContainer: ModelContainer?
    @State private var databaseError: String?

    init() {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration()
        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: NovelMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            modelContainer = nil
            _databaseError = State(initialValue: error.localizedDescription)
            #if DEBUG
            print("⚠️ ModelContainer 初始化失敗：\(error)")
            #endif
        }

        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                LibraryView()
                    .environment(ttsService)
                    .modelContainer(modelContainer)
            } else {
                DatabaseErrorView(errorMessage: databaseError ?? "")
            }
        }
    }

    /// 設定音頻會話，支援背景播放
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("音頻會話設定失敗：\(error)")
            #endif
        }
    }
}
