import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
import SwiftData

@MainActor
final class RadioPlayerModel: ObservableObject {

    @Published private(set) var state: StreamState = .idle
    @Published private(set) var nowPlaying: NowPlaying = .offAir
    @Published private(set) var liveShow: LiveShow?
    @Published private(set) var history: [PlayedTrack] = []
    @Published private(set) var connectivity: Connectivity = .good
    var isMuted = false { didSet { player?.isMuted = isMuted } }
    /// Stays at 1 on devices, where the phone's own volume sets the level.
    /// Only the Simulator's stand-in volume slider changes it.
    var volume: Float = 1 { didSet { player?.volume = volume } }
    @Published private(set) var isCurrentTrackLiked = false

    /// RadioCult stream for the station.
    private let streamURL = URL(string: "https://radio-monash.radiocult.fm/stream")!

    private let client = RadioCultClient.shared
    private let modelContext: ModelContext?
    private let schedule: ScheduleStore?
    private let liveActivity = LiveActivityController()

    private var player: AVPlayer?
    private var metadataTimer: AnyCancellable?
    private var statusObservation: NSKeyValueObservation?

    init(modelContext: ModelContext? = nil, schedule: ScheduleStore? = nil) {
        self.modelContext = modelContext
        self.schedule = schedule
    }

    var isOnAir: Bool { liveShow != nil }

    /// While a show is live but no track is identified, the show stands in
    /// for the track instead of "Radio Monash · Default playlist".
    var displayTitle: String {
        isIdentifiedTrack ? nowPlaying.title : liveShow?.name ?? nowPlaying.title
    }

    var displayArtist: String? {
        isIdentifiedTrack || liveShow == nil ? nowPlaying.artist : nil
    }

    private var isIdentifiedTrack: Bool { nowPlaying != .offAir }
    var canLikeCurrentTrack: Bool { modelContext != nil && nowPlaying != .offAir }
    var isBusy: Bool { state == .connecting }

    var elapsed: TimeInterval {
        nowPlaying.startedAt.map { Date().timeIntervalSince($0) } ?? 0
    }

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
        LiveActivityActions.togglePlayback = { [weak self] in self?.togglePlayback() }
        LiveActivityActions.toggleLike = { [weak self] in self?.toggleLike() }
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
        player.isMuted = isMuted
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
        guard canLikeCurrentTrack else { return }
        toggleFavourite(title: nowPlaying.title, artist: nowPlaying.artist,
                        artworkURL: nowPlaying.artworkURL, showName: liveShow?.name)
    }

    func toggleLike(_ track: PlayedTrack, showName: String?) {
        toggleFavourite(title: track.title, artist: track.artist,
                        artworkURL: track.artworkURL, showName: showName)
    }

    private func toggleFavourite(title: String, artist: String, artworkURL: URL?, showName: String?) {
        guard let modelContext else { return }
        if let existing = favourite(key: FavouriteTrack.key(title: title, artist: artist)) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavouriteTrack(title: title, artist: artist, artworkURL: artworkURL, showName: showName))
        }
        try? modelContext.save()
        refreshLikeState()
    }

    func unlike(_ track: FavouriteTrack) {
        guard let modelContext else { return }
        modelContext.delete(track)
        try? modelContext.save()
        refreshLikeState()
    }

    private func favourite(key: String) -> FavouriteTrack? {
        guard let modelContext else { return nil }
        var descriptor = FetchDescriptor<FavouriteTrack>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func refreshLikeState() {
        let key = FavouriteTrack.key(title: nowPlaying.title, artist: nowPlaying.artist)
        setIfChanged(\.isCurrentTrackLiked, favourite(key: key) != nil)
        MPRemoteCommandCenter.shared().likeCommand.isActive = isCurrentTrackLiked
        refreshLiveActivity()
    }

    // MARK: Metadata

    private func startMetadataPolling() {
        Task { await refreshMetadata() }
        metadataTimer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshMetadata() } }
    }

    func refreshMetadata() async {
        do {
            apply(try await client.liveStatus().toNowPlaying())
            setIfChanged(\.connectivity, .good)
        } catch {
            setIfChanged(\.connectivity, (error as? URLError)?.code == .notConnectedToInternet ? .offline : .weak)
        }

        do {
            setIfChanged(\.history, try await client.history(limit: 5).toPlayedTracks())
        } catch {
            // Keep whatever history we already have rather than flashing it empty.
        }
    }

    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        let changed = payload.track != nowPlaying || payload.show != liveShow
        setIfChanged(\.nowPlaying, payload.track)
        setIfChanged(\.liveShow, payload.show)
        guard changed else { return }
        refreshLikeState()
        updateNowPlayingCentre()
    }

    private func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RadioPlayerModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
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
            MPMediaItemPropertyTitle: displayTitle,
            MPMediaItemPropertyArtist: displayArtist ?? "Radio Monash",
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
        if let show = liveShow { info[MPMediaItemPropertyAlbumTitle] = show.name }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        refreshLiveActivity()
    }

    /// Pushes the current state to the Lock Screen Live Activity. Also called
    /// by Settings when the Live Activity toggle changes.
    func refreshLiveActivity() {
        switch state {
        case .idle, .failed:
            liveActivity.sync(nil, canStart: false)
        case .connecting, .playing, .paused:
            let onAir = schedule?.onAir()
            let trackEnd = nowPlaying.duration.flatMap { duration in nowPlaying.startedAt.map { $0 + duration } }
            liveActivity.sync(
                RadioActivityAttributes.ContentState(
                    title: displayTitle,
                    artist: displayArtist ?? "",
                    showBilling: onAir.map { LiveShow(name: $0.series.title, host: $0.series.hosts.first).billing }
                        ?? liveShow?.billing,
                    isPlaying: state == .playing,
                    isLiked: isCurrentTrackLiked,
                    progressStart: onAir?.start ?? nowPlaying.startedAt,
                    progressEnd: onAir?.end ?? trackEnd
                ),
                canStart: state == .playing
            )
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
