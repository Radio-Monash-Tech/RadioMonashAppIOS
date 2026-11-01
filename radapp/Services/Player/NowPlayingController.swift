import MediaPlayer
import UIKit

// the player on the lock screen and in control centre
final class NowPlayingController {
    private let info = MPNowPlayingInfoCenter.default()

    // connects the system's buttons to the player, once per launch
    func configure(play: @escaping () -> Void, pause: @escaping () -> Void, toggle: @escaping () -> Void) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { _ in
            play()
            return .success
        }
        commands.pauseCommand.addTarget { _ in
            pause()
            return .success
        }
        // ios can offer stop instead of pause for live radio
        commands.stopCommand.addTarget { _ in
            pause()
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { _ in
            toggle()
            return .success
        }
        // live radio can't skip or seek, so hide those buttons
        for command in [commands.nextTrackCommand, commands.previousTrackCommand,
                        commands.skipForwardCommand, commands.skipBackwardCommand,
                        commands.changePlaybackPositionCommand] {
            command.isEnabled = false
        }
    }

    func update(title: String, artist: String?, show: String?, isPlaying: Bool, artwork: UIImage?) {
        var values: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist ?? "Radio Monash",
            // shows LIVE instead of a scrubber
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let show {
            values[MPMediaItemPropertyAlbumTitle] = show
        }
        if let artwork {
            values[MPMediaItemPropertyArtwork] = Self.artwork(artwork)
        }
        info.nowPlayingInfo = values
        info.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }

    // nonisolated because ios calls the handler on a background thread
    nonisolated private static func artwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in
            image
        }
    }
}
