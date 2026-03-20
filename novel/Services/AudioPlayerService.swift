import Foundation
import AVFoundation

/// MP3 音訊播放服務：播放 Edge TTS 等引擎回傳的音訊 Data
final class AudioPlayerService: NSObject {
    private var audioPlayer: AVAudioPlayer?

    /// 播放完成時的回調
    var onPlaybackFinished: (() -> Void)?

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// 播放 MP3 音訊資料
    func play(data: Data) throws {
        audioPlayer?.stop()
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    /// 暫停播放
    func pause() {
        audioPlayer?.pause()
    }

    /// 恢復播放
    func resume() {
        audioPlayer?.play()
    }

    /// 停止播放
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.onPlaybackFinished?()
        }
    }
}
