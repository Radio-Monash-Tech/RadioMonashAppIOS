import SwiftUI
import Combine
import SwiftData

/// The station player the app's views watch. It ties together the stream,
/// the audio session, the RadioCult feed, liked songs and the system players.
@MainActor
final class RadioPlayerModel: ObservableObject {

    @Published private(set) var state: StreamState = .idle { didSet { trackListening() } }
    @Published private(set) var nowPlaying: NowPlaying = .offAir
    @Published private(set) var liveShow: LiveShow? { didSet { trackListening() } }
    @Published private(set) var history: [PlayedTrack] = []
    @Published private(set) var connectivity: Connectivity = .good
    @Published private(set) var isCurrentTrackLiked = false
    @Published private(set) var sleepTimerEndsAt: Date?
    var isMuted = false { didSet { stream.isMuted = isMuted } }
    // Stays at 1 on devices, where the phone's own volume sets the level.
    // Only the Simulator's stand-in volume slider changes it, and the last
    // value is remembered so a relaunch doesn't start at full volume.
    var volume: Float = UserDefaults.standard.object(forKey: RadioPlayerModel.volumeKey) as? Float ?? 1 {
        didSet {
            stream.volume = volume
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }
    private static let volumeKey = "playerVolume"
    static let resumeOnLaunchKey = "resumeOnLaunch"

    private let client = RadioCultClient.shared
    private let stream = RadioStream()
    private let audioSession = RadioAudioSession()
    private let systemPlayers = SystemPlayerSync()
    private let favourites: FavouriteStore?
    private let schedule: ScheduleStore?
    private let listening: ListeningTracker?
    private var trackHistory = TrackHistory()

    private var metadataTimer: AnyCancellable?
    private var foregroundObserver: AnyCancellable?
    private var sleepTimerTask: Task<Void, Never>?
    private var resumeAfterInterruption = false
    private var isSessionPrepared = false

    init(modelContext: ModelContext? = nil, schedule: ScheduleStore? = nil) {
        favourites = modelContext.map(FavouriteStore.init)
        self.schedule = schedule
        listening = modelContext.map(ListeningTracker.init)
        stream.volume = volume
        stream.onStateChange = { [weak self] state in
            self?.state = state
            self?.refreshLiveActivity()
        }
        audioSession.onEvent = { [weak self] in self?.handle($0) }
    }

    /// While a show is live but no track is identified, the show stands in
    /// for the track instead of "Radio Monash · Default playlist".
    var displayTitle: String {
        isIdentifiedTrack ? nowPlaying.title : liveShow?.name ?? nowPlaying.title
    }

    var displayArtist: String? {
        isIdentifiedTrack || liveShow == nil ? nowPlaying.artist : nil
    }

    private var isIdentifiedTrack: Bool { nowPlaying != .offAir }
    /// The station logo stands in for cover art only while no track is identified.
    var showsStationLogo: Bool { !isIdentifiedTrack }
    var canLikeCurrentTrack: Bool { favourites != nil && isIdentifiedTrack }
    var isBusy: Bool { state == .connecting }
    private var isActive: Bool { state == .playing || state == .connecting }

    // MARK: Session

    /// Runs once per launch; the root view's `.task` can fire again if it reappears.
    func prepareSession() {
        guard !isSessionPrepared else { return }
        isSessionPrepared = true
        configureAudioSession()
        audioSession.observe()
        LiveActivityActions.togglePlayback = { [weak self] in self?.togglePlayback() }
        LiveActivityActions.toggleLike = { [weak self] in self?.toggleLike() }
        systemPlayers.configure(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.stop() },
            toggle: { [weak self] in self?.togglePlayback() }
        )
        startMetadataPolling()

        let resumeOnLaunch = UserDefaults.standard.object(forKey: Self.resumeOnLaunchKey) as? Bool ?? false
        if resumeOnLaunch, state == .idle { play() }
    }

    private func configureAudioSession() {
        do {
            try audioSession.configure()
        } catch {
            stream.fail("Couldn't start audio session.")
        }
    }

    private func handle(_ event: RadioAudioSession.Event) {
        switch event {
        case .interruptionBegan:
            guard isActive else { return }
            resumeAfterInterruption = true
            stop()
        case .interruptionEnded(let shouldResume):
            guard resumeAfterInterruption else { return }
            resumeAfterInterruption = false
            if shouldResume { play() }
        case .outputLost:
            // Match iOS pausing us rather than claim to be playing in silence.
            if state == .playing { stop() }
        case .mediaServicesReset:
            let wasActive = isActive
            configureAudioSession()
            if wasActive { play() }
        }
    }

    // MARK: Transport

    func togglePlayback() {
        switch state {
        case .playing:
            stop()
        case .paused, .idle, .failed:
            play()
        case .connecting:
            break
        }
    }

    func play() { stream.play() }

    func retry() { play() }

    private func stop() { stream.stop() }

    // MARK: Sleep timer

    /// When the on-air show ends, if the schedule knows it; offered as a sleep timer option.
    var currentShowEndsAt: Date? {
        schedule?.onAir()?.end
    }

    /// Stops the stream at `date`. Passing `nil` cancels the timer.
    func setSleepTimer(endingAt date: Date?) {
        sleepTimerTask?.cancel()
        sleepTimerEndsAt = date
        guard let date else { return }
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.sleepTimerFired()
        }
    }

    private func sleepTimerFired() {
        sleepTimerEndsAt = nil
        sleepTimerTask = nil
        if isActive { stop() }
    }

    // MARK: Likes

    func toggleLike() {
        guard canLikeCurrentTrack else { return }
        favourites?.toggle(title: nowPlaying.title, artist: nowPlaying.artist,
                           artworkURL: nowPlaying.artworkURL, showName: liveShow?.name)
        refreshLikeState()
    }

    func toggleLike(_ track: PlayedTrack, showName: String?) {
        favourites?.toggle(title: track.title, artist: track.artist,
                           artworkURL: track.artworkURL, showName: showName)
        refreshLikeState()
    }

    func unlike(_ track: FavouriteTrack) {
        favourites?.remove(track)
        refreshLikeState()
    }

    private func refreshLikeState() {
        let isLiked = favourites?.contains(title: nowPlaying.title, artist: nowPlaying.artist) ?? false
        setIfChanged(\.isCurrentTrackLiked, isLiked)
        refreshLiveActivity()
    }

    // MARK: Metadata

    private func startMetadataPolling() {
        Task { await refreshMetadata() }
        metadataTimer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshMetadata() } }
        // iOS suspends the app in the background when nothing is playing, so
        // catch up as soon as it's back rather than waiting for the next tick.
        foregroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
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
            trackHistory.reported = try await client.history(limit: TrackHistory.limit).toPlayedTracks()
        } catch {
            // Keep whatever history we already have rather than flashing it empty.
        }
        setIfChanged(\.history, trackHistory.recent(excluding: nowPlaying))
    }

    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        let changed = payload.track != nowPlaying || payload.show != liveShow
        if payload.track != nowPlaying { trackHistory.recordFinished(nowPlaying) }
        setIfChanged(\.nowPlaying, payload.track)
        setIfChanged(\.liveShow, payload.show)
        guard changed else { return }
        refreshLikeState()
        systemPlayers.setArtwork(showsStationLogo ? nil : nowPlaying.artworkURL)
    }

    private func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RadioPlayerModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    // MARK: Listening statistics

    /// The show being listened to, linked to its schedule entry when the
    /// schedule has it so Listening Statistics can open the show's page.
    private var listeningShow: ListeningTracker.Show? {
        guard let liveShow else { return nil }
        let series = schedule?.onAir()?.series
        let matches = series?.title.localizedCaseInsensitiveCompare(liveShow.name) == .orderedSame
        return .init(name: liveShow.name, seriesID: matches ? series?.id : nil)
    }

    private func trackListening() {
        listening?.update(state: state, show: listeningShow)
    }

    func resetListeningStatistics() {
        listening?.reset()
        trackListening()
    }

    // MARK: Live Activity

    /// Pushes the current state to the Lock Screen Live Activity and the
    /// system player. Also called by Settings when the Live Activity toggle changes.
    func refreshLiveActivity() {
        systemPlayers.update(.init(
            state: state,
            title: displayTitle,
            artist: displayArtist,
            show: liveShow?.name,
            isLiked: isCurrentTrackLiked,
            startedAt: nowPlaying.startedAt,
            duration: nowPlaying.duration
        ))
    }
}
