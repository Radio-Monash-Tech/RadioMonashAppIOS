import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class RadioPlayerModel: ObservableObject {

    @Published private(set) var state: StreamState = .idle
    @Published private(set) var nowPlaying: NowPlaying = .offAir
    @Published private(set) var liveShow: LiveShow?
    @Published private(set) var history: [PlayedTrack] = []
    @Published private(set) var connectivity: Connectivity = .good
    @Published var volume: Float = 0.72 { didSet { player?.volume = volume } }
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isCurrentTrackLiked = false

    /// RadioCult stream + metadata endpoints for the station.
    private let streamURL = URL(string: "https://radio-monash.radiocult.fm/stream")!
    private let metadataURL = URL(string: "https://api.radiocult.fm/api/station/radio-monash/schedule/live")!
    private let historyURL = URL(string: "https://api.radiocult.fm/api/station/radio-monash/streaming/history/latest-results?limit=5")!

    /// Publishable (read-only) key — safe for client distribution per RadioCult's docs.
    /// TODO: move to a gitignored config file before this repo goes public.
    private let apiKey = "pk_4bf03d42acb4441c96c73e33c8b22491"

    private var player: AVPlayer?
    private var metadataTimer: AnyCancellable?
    private var tick: AnyCancellable?
    private var statusObservation: NSKeyValueObservation?

    var isOnAir: Bool { liveShow != nil }
    var isBusy: Bool { state == .connecting }

    /// 0…1 progress through the current track. Live radio has no seekable
    /// timeline, so this is derived from the metadata's start time.
    var progress: Double {
        guard let duration = nowPlaying.duration, duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    var elapsedLabel: String { Self.clock(elapsed) }

    var remainingLabel: String {
        guard let duration = nowPlaying.duration else { return "LIVE" }
        return "-" + Self.clock(max(0, duration - elapsed))
    }

    // MARK: Session

    func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps audio alive when the screen locks and honours
            // the silent switch the way a radio should.
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            state = .failed("Couldn't start audio session.")
        }
        configureRemoteCommands()
        startMetadataPolling()
    }

    // MARK: Transport

    func togglePlayback() {
        switch state {
        case .playing:
            player?.pause()
            state = .paused
        case .paused:
            player?.play()
            state = .playing
        case .idle, .failed:
            play()
        case .connecting:
            break
        }
        updateNowPlayingCentre()
    }

    func play() {
        state = .connecting

        let item = AVPlayerItem(url: streamURL)
        let player = AVPlayer(playerItem: item)
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.player?.play()
                    self.state = .playing
                    self.startTicking()
                case .failed:
                    self.state = .failed(item.error?.localizedDescription
                        ?? "We couldn't reach the stream.")
                default:
                    break
                }
                self.updateNowPlayingCentre()
            }
        }
    }

    func retry() { play() }

    func toggleLike() {
        isCurrentTrackLiked.toggle()
        // Persist to SwiftData alongside the show it played on.
    }

    // MARK: Metadata

    private func startMetadataPolling() {
        Task { await refreshMetadata() }
        metadataTimer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshMetadata() } }
    }

    private func startTicking() {
        tick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.nowPlaying.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
    }

    func refreshMetadata() async {
        do {
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(metadataURL))
            let payload = try JSONDecoder().decode(ScheduleLiveResponse.self, from: data)
            apply(payload.toNowPlaying())
            connectivity = .good
        } catch {
            connectivity = (error as? URLError)?.code == .notConnectedToInternet ? .offline : .weak
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: authorizedRequest(historyURL))
            history = try JSONDecoder().decode(HistoryResponse.self, from: data).toPlayedTracks()
        } catch {
            // Keep whatever history we already have rather than flashing it empty.
        }
    }

    private func authorizedRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        return request
    }

    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        nowPlaying = payload.track
        liveShow = payload.show
        if let start = payload.track.startedAt {
            elapsed = Date().timeIntervalSince(start)
        }
        isCurrentTrackLiked = false // re-query SwiftData for this track id
        updateNowPlayingCentre()
    }

    // MARK: Now Playing Centre + Live Activity source of truth

    private func configureRemoteCommands() {
        let centre = MPRemoteCommandCenter.shared()
        centre.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        centre.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
        centre.likeCommand.isEnabled = true
        centre.likeCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggleLike() }
            return .success
        }
        // Live radio isn't scrubbable — don't advertise controls that lie.
        centre.skipForwardCommand.isEnabled = false
        centre.skipBackwardCommand.isEnabled = false
        centre.changePlaybackPositionCommand.isEnabled = false
    }

    private func updateNowPlayingCentre() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying.title,
            MPMediaItemPropertyArtist: nowPlaying.artist,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
        if let show = liveShow { info[MPMediaItemPropertyAlbumTitle] = show.name }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
