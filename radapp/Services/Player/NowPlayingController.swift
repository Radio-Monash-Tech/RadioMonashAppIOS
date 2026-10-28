import MediaPlayer
import UIKit

// The system player on the Lock Screen and in Control Centre
final class NowPlayingController {
    private let info = MPNowPlayingInfoCenter.default()

    // Wires the system's buttons to the player. Call once per launch.
    func configure(play: @escaping () -> Void, pause: @escaping () -> Void, toggle: @escaping () -> Void) {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { _ in play(); return .success }
        commands.pauseCommand.addTarget { _ in pause(); return .success }
        // iOS can offer Stop rather than Pause for a live stream.
        commands.stopCommand.addTarget { _ in pause(); return .success }
        commands.togglePlayPauseCommand.addTarget { _ in toggle(); return .success }
        // Live radio can't skip or seek, so iOS hides those buttons.
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
            // Shows LIVE instead of a scrubber.
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let show { values[MPMediaItemPropertyAlbumTitle] = show }
        if let artwork { values[MPMediaItemPropertyArtwork] = Self.artwork(artwork) }
        info.nowPlayingInfo = values
        info.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        info.nowPlayingInfo = nil
        info.playbackState = .stopped
    }

    // iOS calls the handler on a background thread, so it can't be a
    // main-actor closure (the project's default) without crashing.
    nonisolated private static func artwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
    }
}
