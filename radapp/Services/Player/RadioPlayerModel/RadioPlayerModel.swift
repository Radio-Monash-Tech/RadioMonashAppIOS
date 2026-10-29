import SwiftUI
import Combine
import SwiftData

/// The station player the app's views watch. It ties together the stream,
/// the audio session, the RadioCult feed, liked songs and the system players.
@MainActor
final class RadioPlayerModel: ObservableObject {

    @Published private(set) var state: StreamState = .idle {
        didSet {
            trackListening()
            captions.playbackChanged(isPlaying: state == .playing)
            // Catch up straight away when listening (re)starts.
            if state == .playing, oldValue != .playing { restartPolling() }
        }
    }
    // Set by the extensions in this folder, which Swift can't allow with
    // `private(set)` across files. Only the player should change these.
    @Published var nowPlaying: NowPlaying = .offAir { didSet { updateCaptions() } }
    @Published var liveShow: LiveShow? {
        didSet {
            trackListening()
            updateCaptions()
        }
    }
    @Published var history: [PlayedTrack] = []
    @Published var connectivity: Connectivity = .good
    @Published var isCurrentTrackLiked = false
    @Published var sleepTimerEndsAt: Date?
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

    let client = RadioCultClient.shared
    let stream = RadioStream()
    let audioSession = RadioAudioSession()
    let systemPlayers = SystemPlayerSync()
    let captions: CaptionCoordinator
    let favourites: FavouriteStore?
    let schedule: ScheduleStore?
    let listening: ListeningTracker?
    var trackHistory = TrackHistory()

    var pollTask: Task<Void, Never>?
    var foregroundObserver: AnyCancellable?
    var sleepTimerTask: Task<Void, Never>?
    var resumeAfterInterruption = false
    var isSessionPrepared = false

    init(modelContext: ModelContext? = nil, schedule: ScheduleStore? = nil) {
        favourites = modelContext.map(FavouriteStore.init)
        self.schedule = schedule
        listening = modelContext.map(ListeningTracker.init)
        captions = CaptionCoordinator(modelContext: modelContext)
        stream.volume = volume
        stream.onItemReady = { [weak self] in self?.captions.playerItemReady($0) }
        stream.onStateChange = { [weak self] state in
            self?.state = state
            self?.refreshSystemPlayers()
        }
        audioSession.onEvent = { [weak self] in self?.handle($0) }
        // Wired up front: a widget button can launch the app
        // in the background, before any view has appeared to prepare the session.
        WidgetActions.togglePlayback = { [weak self] in
            self?.prepareSession()
            self?.togglePlayback()
        }
        WidgetActions.toggleLike = { [weak self] in self?.toggleLike() }
    }

    /// While a show is on air its name stands in for the track; otherwise
    /// the song and artist show.
    var displayTitle: String {
        liveShow?.name ?? nowPlaying.title
    }

    var displayArtist: String? {
        liveShow == nil ? nowPlaying.artist : nil
    }

    /// RadioCult named the song on air, so it can be liked or looked up.
    var isIdentifiedTrack: Bool { nowPlaying != .offAir }
    /// The station logo stands in for cover art while a show is on air, when
    /// no track is identified, and when RadioCult has no cover for the track.
    var showsStationLogo: Bool { liveShow != nil || !isIdentifiedTrack || nowPlaying.artworkURL == nil }
    var canLikeCurrentTrack: Bool { favourites != nil && isIdentifiedTrack }
    var isBusy: Bool { state == .connecting }
    var isActive: Bool { state == .playing || state == .connecting }

    /// Tells Live Captions what RadioCult says is on, plus names it should
    /// expect to hear: the show, today's shows and hosts, and recent artists.
    func updateCaptions() {
        var names = ["Radio Monash"]
        if let liveShow { names.append(liveShow.name) }
        if let schedule {
            for show in schedule.shows(on: .now) {
                names.append(show.series.title)
                names += show.series.hosts
            }
        }
        names += history.prefix(20).map(\.artist)
        var seen = Set<String>()
        let vocabulary = names.filter { !$0.isEmpty && seen.insert($0).inserted }
        captions.stationChanged(liveShow: liveShow, nowPlaying: nowPlaying, vocabulary: vocabulary)
    }
}
