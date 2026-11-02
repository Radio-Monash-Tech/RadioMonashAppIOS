import SwiftUI
import Combine
import SwiftData

// the player every screen watches: stream, song info, likes and system players
// @MainActor runs this on the main thread
@MainActor
final class RadioPlayerModel: ObservableObject {

    // MARK: - State screens watch

    // @Published property wrapper, views watching this object redraw when it changes
    @Published private(set) var state: StreamState = .idle {
        didSet {
            trackListening()
            captions.playbackChanged(isPlaying: state == .playing)
            // catch up straight away when listening starts again
            if state == .playing, oldValue != .playing {
                restartPolling()
            }
        }
    }
    // not private(set), because the extension files set them; only the player should
    @Published var nowPlaying: NowPlaying = .offAir {
        didSet {
            updateCaptions()
        }
    }
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
    var isMuted = false {
        didSet {
            stream.isMuted = isMuted
        }
    }
    // only the simulator's slider changes this; remembered between launches
    var volume: Float = UserDefaults.standard.object(forKey: RadioPlayerModel.volumeKey) as? Float ?? 1 {
        didSet {
            stream.volume = volume
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }

    // MARK: - Settings keys

    private static let volumeKey = "playerVolume"
    static let resumeOnLaunchKey = "resumeOnLaunch"

    // MARK: - Services

    let client = RadioCultClient.shared
    let stream = RadioStream()
    let audioSession = RadioAudioSession()
    let systemPlayers = SystemPlayerSync()
    let captions: CaptionCoordinator
    // nil without a database, e.g. in previews
    let favourites: FavouriteStore?
    let schedule: ScheduleStore?
    let listening: ListeningTracker?
    var trackHistory = TrackHistory()

    // MARK: - Background work

    var pollTask: Task<Void, Never>?
    var foregroundObserver: AnyCancellable?
    var sleepTimerTask: Task<Void, Never>?
    // a call paused us, so play again when it ends
    var resumeAfterInterruption = false
    var isSessionPrepared = false

    // MARK: - Init

    // init sets up a new instance
    init(modelContext: ModelContext? = nil, schedule: ScheduleStore? = nil) {
        favourites = modelContext.map(FavouriteStore.init)
        self.schedule = schedule
        listening = modelContext.map(ListeningTracker.init)
        captions = CaptionCoordinator()
        stream.volume = volume
        // captions attach to each new connection
        stream.onItemReady = { [weak self] item in
            self?.captions.playerItemReady(item)
        }
        stream.onStateChange = { [weak self] state in
            self?.state = state
            self?.refreshSystemPlayers()
        }
        audioSession.onEvent = { [weak self] event in
            self?.handle(event)
        }
        // set up now, since a widget button can launch the app before any screen appears
        WidgetActions.togglePlayback = { [weak self] in
            self?.prepareSession()
            self?.togglePlayback()
        }
        WidgetActions.toggleLike = { [weak self] in
            self?.toggleLike()
        }
    }

    // MARK: - Display helpers

    // the show's name while one is on, otherwise the song
    var displayTitle: String {
        liveShow?.name ?? nowPlaying.title
    }

    // the artist, hidden while a show is on
    var displayArtist: String? {
        if liveShow == nil {
            return nowPlaying.artist
        }
        return nil
    }

    // radiocult named the song, so it can be liked or looked up
    var isIdentifiedTrack: Bool {
        nowPlaying != .offAir
    }

    // the logo during a show, with no song named, or with no cover art
    var showsStationLogo: Bool {
        liveShow != nil || !isIdentifiedTrack || nowPlaying.artworkURL == nil
    }

    var canLikeCurrentTrack: Bool {
        favourites != nil && isIdentifiedTrack
    }

    var isBusy: Bool {
        state == .connecting
    }

    var isActive: Bool {
        state == .playing || state == .connecting
    }

    // MARK: - Captions

    // tells captions what's on, and names it should expect to hear
    func updateCaptions() {
        var names = ["Radio Monash"]
        if let liveShow {
            names.append(liveShow.name)
        }
        if let schedule {
            for show in schedule.shows(on: .now) {
                names.append(show.series.title)
                names += show.series.hosts
            }
        }
        names += history.prefix(20).map(\.artist)
        // drop empty names and repeats
        var seen = Set<String>()
        let vocabulary = names.filter { name in
            !name.isEmpty && seen.insert(name).inserted
        }
        captions.stationChanged(liveShow: liveShow, nowPlaying: nowPlaying, vocabulary: vocabulary)
    }
}
