import Foundation
import MediaPlayer

/// 鎖定畫面 / 控制中心整合服務
@Observable
class NowPlayingService {
    private var isSetup = false

    /// 設定遠端控制命令（播放/暫停/上一段/下一段）
    func setupRemoteCommands(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNextTrack: @escaping () -> Void,
        onPreviousTrack: @escaping () -> Void
    ) {
        guard !isSetup else { return }
        isSetup = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { _ in
            onNextTrack()
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { _ in
            onPreviousTrack()
            return .success
        }

        // 停用不需要的控制
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { _ in
            // 切換播放/暫停
            return .success
        }
    }

    /// 更新鎖定畫面顯示的資訊
    func updateNowPlaying(
        bookTitle: String,
        chapterTitle: String,
        paragraphIndex: Int,
        totalParagraphs: Int,
        isPlaying: Bool
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = chapterTitle
        info[MPMediaItemPropertyArtist] = bookTitle
        info[MPMediaItemPropertyAlbumTitle] = bookTitle
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(paragraphIndex)
        info[MPMediaItemPropertyPlaybackDuration] = Double(totalParagraphs)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 清除鎖定畫面資訊
    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
