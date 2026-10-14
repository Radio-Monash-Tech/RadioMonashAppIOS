import SwiftUI
import AVFoundation
import Combine
import SwiftData

@MainActor
final class RadioPlayerModel: ObservableObject {

    @Published private(set) var state: StreamState = .idle { didSet { trackListening() } }
    @Published private(set) var nowPlaying: NowPlaying = .offAir
    @Published private(set) var liveShow: LiveShow? { didSet { trackListening() } }
    @Published private(set) var history: [PlayedTrack] = []
    @Published private(set) var connectivity: Connectivity = .good
    var isMuted = false { didSet { player?.isMuted = isMuted } }
    /// Stays at 1 on devices, where the phone's own volume sets the level.
    /// Only the Simulator's stand-in volume slider changes it, and the last
    /// value is remembered so a relaunch doesn't start at full volume.
    var volume: Float = UserDefaults.standard.object(forKey: RadioPlayerModel.volumeKey) as? Float ?? 1 {
        didSet {
            player?.volume = volume
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }
    private static let volumeKey = "playerVolume"
    @Published private(set) var isCurrentTrackLiked = false
    @Published private(set) var sleepTimerEndsAt: Date?

    /// RadioCult stream for the station.
    private let streamURL = URL(string: "https://radio-monash.radiocult.fm/stream")!

    private let client = RadioCultClient.shared
    private let modelContext: ModelContext?
    private let schedule: ScheduleStore?
    private let listening: ListeningTracker?
    private let liveActivity = LiveActivityController()
    private let widgetArtwork = WidgetArtworkStore()
    private var widgetArtworkFileName: String?
    private var widgetArtworkTask: Task<Void, Never>?

    private var player: AVPlayer?
    private var metadataTimer: AnyCancellable?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var streamSubscriptions = Set<AnyCancellable>()
    private var sessionSubscriptions = Set<AnyCancellable>()
    private var stallWatchdog: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private var reconnectBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var resumeAfterInterruption = false
    private var isSessionPrepared = false
    /// Recently played as RadioCult reports it, and songs the app saw finish on the live feed.
    private var reportedHistory: [PlayedTrack] = []
    private var observedHistory: [PlayedTrack] = []
    private static let historyLimit = 5
    private var sleepTimerTask: Task<Void, Never>?

    private static let stallTimeout: TimeInterval = 12
    private static let maxReconnectAttempts = 6

    init(modelContext: ModelContext? = nil, schedule: ScheduleStore? = nil) {
        self.modelContext = modelContext
        self.schedule = schedule
        listening = modelContext.map(ListeningTracker.init)
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
    /// The station logo stands in for cover art only while no track is identified.
    var showsStationLogo: Bool { !isIdentifiedTrack }
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

    static let resumeOnLaunchKey = "resumeOnLaunch"

    /// Runs once per launch; the root view's `.task` can fire again if it reappears.
    func prepareSession() {
        guard !isSessionPrepared else { return }
        isSessionPrepared = true
        configureSession()
        observeAudioSession()
        LiveActivityActions.togglePlayback = { [weak self] in self?.togglePlayback() }
        LiveActivityActions.toggleLike = { [weak self] in self?.toggleLike() }
        startMetadataPolling()

        let resumeOnLaunch = UserDefaults.standard.object(forKey: Self.resumeOnLaunchKey) as? Bool ?? false
        if resumeOnLaunch, state == .idle { play() }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .playback keeps audio alive when the screen locks and ignores
            // the silent switch the way a radio should. .mixWithOthers keeps
            // iOS from adopting us as the Now Playing app, so the Live
            // Activity is the only Lock Screen player.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            state = .failed("Couldn't start audio session.")
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

    /// Always opens a fresh connection. A live stream that has sat paused goes
    /// stale, and resuming it plays silence instead of the station.
    func play() {
        reconnectAttempts = 0
        startStream()
    }

    func retry() { play() }

    /// Pausing live radio drops the connection; `play()` rejoins it live.
    private func stop() {
        tearDownStream()
        state = .paused
        refreshLiveActivity()
    }

    private func startStream() {
        tearDownStream()
        state = .connecting
        refreshLiveActivity()
        // The session can be deactivated while the app sat suspended.
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: streamURL)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor in
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    guard self.state == .connecting else { return }
                    self.player?.play()
                    self.state = .playing
                    self.endReconnectBackgroundTask()
                    self.refreshLiveActivity()
                case .failed:
                    self.streamDropped()
                default:
                    break
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard let self, self.player === player else { return }
                self.timeControlStatusChanged(status)
            }
        }

        // The server closing the connection ends the item even though live
        // radio never really ends, so both notifications mean "reconnect".
        let center = NotificationCenter.default
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            center.publisher(for: name, object: item)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.player?.currentItem === item else { return }
                        self.streamDropped()
                    }
                }
                .store(in: &streamSubscriptions)
        }
    }

    private func tearDownStream() {
        reconnectTask?.cancel()
        reconnectTask = nil
        stallWatchdog?.cancel()
        stallWatchdog = nil
        statusObservation = nil
        timeControlObservation = nil
        streamSubscriptions.removeAll()
        player?.pause()
        player = nil
        endReconnectBackgroundTask()
    }

    private func timeControlStatusChanged(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            stallWatchdog?.cancel()
            stallWatchdog = nil
            reconnectAttempts = 0
        case .waitingToPlayAtSpecifiedRate where state == .playing:
            // AVPlayer rides out short buffering on its own; a stream that
            // stays stuck has usually lost its connection for good.
            guard stallWatchdog == nil else { return }
            stallWatchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.stallTimeout))
                guard !Task.isCancelled, let self else { return }
                self.stallWatchdog = nil
                if self.player?.timeControlStatus != .playing { self.streamDropped() }
            }
        default:
            break
        }
    }

    /// Reconnects after the stream drops mid-listen, backing off between
    /// attempts, and only reports a failure once every attempt has failed.
    private func streamDropped() {
        guard state == .playing || state == .connecting else { return }
        // A first connection that fails is reported straight away; only a
        // stream that was already playing (or reconnecting) retries.
        let isRecovering = state == .playing || reconnectAttempts > 0
        guard isRecovering, reconnectAttempts < Self.maxReconnectAttempts else {
            tearDownStream()
            state = .failed(isRecovering ? "Lost connection to the stream." : "We couldn't reach the stream.")
            refreshLiveActivity()
            return
        }
        reconnectAttempts += 1
        let delay = min(16, pow(2, Double(reconnectAttempts - 1)))

        tearDownStream()
        state = .connecting
        refreshLiveActivity()
        // With no audio playing, iOS suspends a backgrounded app within
        // seconds; ask for time so the reconnect still happens.
        reconnectBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endReconnectBackgroundTask()
        }
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.state == .connecting else { return }
            self.startStream()
            // startStream() ended the old background task; keep one alive
            // until the new connection is ready.
            self.reconnectBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endReconnectBackgroundTask()
            }
        }
    }

    private func endReconnectBackgroundTask() {
        guard reconnectBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(reconnectBackgroundTask)
        reconnectBackgroundTask = .invalid
    }

    // MARK: Audio session events

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        center.publisher(for: AVAudioSession.interruptionNotification, object: session)
            .sink { [weak self] note in
                let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                Task { @MainActor in self?.handleInterruption(type, options: options) }
            }
            .store(in: &sessionSubscriptions)

        center.publisher(for: AVAudioSession.routeChangeNotification, object: session)
            .sink { [weak self] note in
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                    .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                Task { @MainActor in
                    // Unplugged headphones: iOS pauses us, so match it rather
                    // than claim to be playing in silence.
                    guard let self, reason == .oldDeviceUnavailable, self.state == .playing else { return }
                    self.stop()
                }
            }
            .store(in: &sessionSubscriptions)

        center.publisher(for: AVAudioSession.mediaServicesWereResetNotification, object: session)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let wasPlaying = self.state == .playing || self.state == .connecting
                    self.configureSession()
                    if wasPlaying { self.play() }
                }
            }
            .store(in: &sessionSubscriptions)
    }

    private func handleInterruption(_ type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            // A phone call or alarm took the audio; iOS has already paused us.
            guard state == .playing || state == .connecting else { return }
            resumeAfterInterruption = true
            stop()
        case .ended:
            guard resumeAfterInterruption else { return }
            resumeAfterInterruption = false
            if options.contains(.shouldResume) { play() }
        default:
            break
        }
    }

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
        guard state == .playing || state == .connecting else { return }
        stop()
    }

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
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in Task { await self?.refreshMetadata() } }
            .store(in: &sessionSubscriptions)
    }

    func refreshMetadata() async {
        do {
            apply(try await client.liveStatus().toNowPlaying())
            setIfChanged(\.connectivity, .good)
        } catch {
            setIfChanged(\.connectivity, (error as? URLError)?.code == .notConnectedToInternet ? .offline : .weak)
        }

        do {
            reportedHistory = try await client.history(limit: Self.historyLimit).toPlayedTracks()
        } catch {
            // Keep whatever history we already have rather than flashing it empty.
        }
        rebuildHistory()
    }

    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        let changed = payload.track != nowPlaying || payload.show != liveShow
        if payload.track != nowPlaying { recordFinishedTrack() }
        setIfChanged(\.nowPlaying, payload.track)
        setIfChanged(\.liveShow, payload.show)
        guard changed else { return }
        refreshLikeState()
        refreshWidgetArtwork()
    }

    /// RadioCult only lists a song in its history a while after it ends, so
    /// the song that just finished would be missing. The live feed moving on
    /// means it finished, so it's added straight away.
    private func recordFinishedTrack() {
        guard isIdentifiedTrack, let startedAt = nowPlaying.startedAt else { return }
        let track = PlayedTrack(
            id: "live-\(Int(startedAt.timeIntervalSince1970))",
            title: nowPlaying.title,
            artist: nowPlaying.artist,
            playedAt: startedAt,
            artworkURL: nowPlaying.artworkURL
        )
        guard !observedHistory.contains(where: { $0.isSamePlay(as: track) }) else { return }
        observedHistory.insert(track, at: 0)
        observedHistory = Array(observedHistory.prefix(Self.historyLimit))
    }

    /// RadioCult's history plus songs the app saw finish, newest first. When
    /// both have a song, RadioCult's entry wins; the song on air now is left out.
    private func rebuildHistory() {
        var merged = reportedHistory
        for track in observedHistory where !merged.contains(where: { $0.isSamePlay(as: track) }) {
            merged.append(track)
        }
        let playing = nowPlaying.startedAt.map {
            PlayedTrack(id: "", title: nowPlaying.title, artist: nowPlaying.artist, playedAt: $0, artworkURL: nil)
        }
        let recent = merged
            .filter { track in playing.map { !track.isSamePlay(as: $0) } ?? true }
            .sorted { $0.playedAt > $1.playedAt }
            .prefix(Self.historyLimit)
        setIfChanged(\.history, Array(recent))
    }

    /// Saves the RadioCult cover for the Live Activity. Unknown tracks, live
    /// shows and tracks without a cover fall back to the station logo.
    private func refreshWidgetArtwork() {
        widgetArtworkTask?.cancel()
        guard !showsStationLogo, let url = nowPlaying.artworkURL else {
            widgetArtworkFileName = nil
            refreshLiveActivity()
            return
        }
        widgetArtworkTask = Task { [weak self] in
            guard let self else { return }
            let name = await widgetArtwork.save(url)
            guard !Task.isCancelled else { return }
            widgetArtworkFileName = name
            refreshLiveActivity()
        }
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

    /// Pushes the current state to the Lock Screen Live Activity. Also called
    /// by Settings when the Live Activity toggle changes.
    func refreshLiveActivity() {
        switch state {
        case .idle, .failed:
            liveActivity.sync(nil, canStart: false)
        case .connecting, .playing, .paused:
            let trackEnd = nowPlaying.duration.flatMap { duration in nowPlaying.startedAt.map { $0 + duration } }
            liveActivity.sync(
                RadioActivityAttributes.ContentState(
                    title: displayTitle,
                    artist: displayArtist ?? "",
                    isPlaying: state == .playing,
                    isLiked: isCurrentTrackLiked,
                    progressStart: nowPlaying.startedAt,
                    progressEnd: trackEnd,
                    artworkFileName: widgetArtworkFileName
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
