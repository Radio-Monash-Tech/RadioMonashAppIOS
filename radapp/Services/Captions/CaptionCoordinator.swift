import AVFoundation
import Synchronization
import Observation

// what the caption screens read, runs captions only while they're on and the radio plays
// @MainActor runs this on the main thread
@MainActor
// @Observable macro, SwiftUI redraws when these properties change
@Observable
final class CaptionCoordinator {
    // MARK: - State the screens read

    // whether the speech model is ready
    private(set) var availability: CaptionAvailability = .checking
    // the CC switch, remembered between launches
    var isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled) {
        // run immediately after the value changed
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            refresh()
        }
    }
    // caption song lyrics too, not just talk
    var captionsMusic = UserDefaults.standard.object(forKey: Keys.music) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(captionsMusic, forKey: Keys.music)
            setIncludesMusic?(captionsMusic)
        }
    }
    // caption size from the Aa menu
    var textSize = CaptionTextSize(rawValue: UserDefaults.standard.string(forKey: Keys.textSize) ?? "") ?? .system {
        didSet {
            UserDefaults.standard.set(textSize.rawValue, forKey: Keys.textSize)
        }
    }
    // whether the intro sheet has been seen
    private(set) var hasSeenIntro = UserDefaults.standard.bool(forKey: Keys.seenIntro)

    // talk or music while running, nil while starting or stopped
    private(set) var mode: CaptionMode?
    // whether the engine is running right now
    private(set) var isRunning = false
    // finished lines, oldest first
    private(set) var lines: [CaptionLine] = []
    // the line still being heard, its words may change
    private(set) var liveLine: CaptionLine?
    // shown on screen when something goes wrong
    private(set) var errorMessage: String?
    // whether the radio is playing
    private(set) var isPlaying = false
    
    // MARK: - Private state

    // Disables observation tracking of a property.
    @ObservationIgnored private let bridge = AudioTapBridge()
    // the current connection, weak so old ones can be freed
    @ObservationIgnored private weak var playerItem: AVPlayerItem?
    // the english picked by the model check
    @ObservationIgnored private var locale: Locale?
    // receives engine events, nil means captions are stopped
    @ObservationIgnored private var runTask: Task<Void, Never>?
    // passes the station hint into the running engine
    @ObservationIgnored private var setHint: ((ContentClassifier.StationHint) -> Void)?
    // passes the music setting into the running engine
    @ObservationIgnored private var setIncludesMusic: ((Bool) -> Void)?
    // reused when the live line finishes, so it doesn't jump
    @ObservationIgnored private var liveLineID = UUID()
    // the show on air, nil during the automated playlist
    @ObservationIgnored private var liveShow: LiveShow?
    // the current song, for lyrics labels
    @ObservationIgnored private var nowPlaying: NowPlaying = .offAir
    // names that help the recogniser spell
    @ObservationIgnored private var vocabulary: [String] = []

    // MARK: - Settings keys

    // userdefaults key names, kept in one place
    private enum Keys {
        static let enabled = "captionsEnabled"
        static let textSize = "captionTextSize"
        static let music = "captionsMusic"
        static let seenIntro = "captionsSeenIntro"
    }

    // MARK: - Init

    // checks the model as soon as the app starts
    // init sets up a new instance
    init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Display helpers

    // lines in a row from the same speaker, grouped for display
    var groups: [CaptionGroup] {
        var allLines = lines
        if let liveLine {
            allLines.append(liveLine)
        }
        var result: [CaptionGroup] = []
        for line in allLines {
            if let last = result.last, last.speaker == line.speaker {
                result[result.count - 1].lines.append(line)
            } else {
                result.append(CaptionGroup(id: line.id, speaker: line.speaker, lines: [line]))
            }
        }
        return result
    }

    // the CC button shows unless this phone can't do captions at all
    var isSupported: Bool {
        switch availability {
        case .checking, .unsupported:
            false
        default:
            true
        }
    }

    // MARK: - Setup and model download

    // the intro and model download come before captions first turn on
    var needsSetup: Bool {
        !hasSeenIntro || availability == .needsDownload
    }

    // called by turn on captions in the setup sheet
    func finishSetup() {
        hasSeenIntro = true
        UserDefaults.standard.set(true, forKey: Keys.seenIntro)
        isEnabled = true
    }

    // finds out whether the speech model is ready
    func checkAvailability() async {
        // guard exits early if the check fails, #available checks the ios version while the app runs
        guard #available(iOS 26, *) else {
            availability = .unsupported("Live Captions need iOS 26 or later.")
            return
        }
        let (availability, locale) = await CaptionModelManager.availability()
        self.availability = availability
        self.locale = locale
        refresh()
    }

    // downloads the speech model and tracks its progress
    func downloadModel() async {
        guard #available(iOS 26, *), let locale else {
            return
        }
        availability = .downloading(0)
        errorMessage = nil
        do {
            try await CaptionModelManager.download(for: locale) { [weak self] fraction in
                self?.availability = .downloading(fraction)
            }
            availability = .ready
        } catch {
            availability = .needsDownload
            errorMessage = "The speech model didn't download. Check your connection and try again."
        }
        refresh()
    }

    // MARK: - Player events

    // a new connection is about to play, the tap goes on now, even with captions off
    func playerItemReady(_ item: AVPlayerItem) {
        guard item !== playerItem else {
            return
        }
        // a reconnect brings a new item, so move to it
        stop()
        playerItem = item
        // skipped where captions can never run, still checking counts as maybe
        if #available(iOS 26, *), isSupported || availability == .checking {
            bridge.install(on: item)
        }
        refresh()
    }

    // the radio started or stopped
    func playbackChanged(isPlaying: Bool) {
        self.isPlaying = isPlaying
        refresh()
    }

    // radiocult's view of what's on, plus names to expect
    func stationChanged(liveShow: LiveShow?, nowPlaying: NowPlaying, vocabulary: [String]) {
        self.liveShow = liveShow
        self.nowPlaying = nowPlaying
        self.vocabulary = vocabulary
        setHint?(hint)
    }

    // MARK: - Starting and stopping

    // no presenter on air means nobody to caption
    private var hint: ContentClassifier.StationHint {
        if liveShow == nil {
            return .automated
        }
        return .presenter
    }

    // starts or stops captions to match the settings and playback
    private func refresh() {
        let shouldRun = isEnabled && availability == .ready && isPlaying && playerItem != nil
        if shouldRun, runTask == nil {
            start()
        } else if !shouldRun, runTask != nil {
            stop()
        }
    }

    // starts the tap copying and runs a new engine in the background
    private func start() {
        guard #available(iOS 26, *), let item = playerItem, let locale else {
            return
        }
        guard bridge.isInstalled(on: item), let audio = bridge.startCapture() else {
            // set up mid-listen on a stream that started without the tap
            errorMessage = "Captions start the next time you press play."
            return
        }
        let engine = CaptionEngine()
        engine.includesMusic.store(captionsMusic, ordering: .relaxed)
        setHint = { hint in
            engine.classifier.setHint(hint)
        }
        setIncludesMusic = { includesMusic in
            engine.includesMusic.store(includesMusic, ordering: .relaxed)
        }
        let (events, continuation) = AsyncStream.makeStream(of: CaptionEvent.self)
        let hint = hint
        let vocabulary = vocabulary
        isRunning = true
        errorMessage = nil
        lines = []
        liveLine = nil

        // the engine runs off the main thread
        Task.detached(priority: .userInitiated) {
            await engine.run(audio: audio, locale: locale, vocabulary: vocabulary, hint: hint, events: continuation)
        }
        // its events come back here
        runTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    // stops the tap, which winds the engine down
    private func stop() {
        // ending the audio winds down the engine
        bridge.stopCapture()
        runTask?.cancel()
        runTask = nil
        setHint = nil
        setIncludesMusic = nil
        isRunning = false
        mode = nil
        // finished lines stay after pausing, only the live one goes
        liveLine = nil
    }

    // MARK: - Engine events

    // turns engine events into lines on screen
    private func handle(_ event: CaptionEvent) {
        switch event {
        case .mode(let newMode):
            guard newMode != mode else {
                return
            }
            mode = newMode
        case .volatile(let text):
            // words still coming in
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                liveLine = nil
            } else {
                liveLine = CaptionLine(id: liveLineID, speaker: speaker, text: text)
            }
        case .final(let text):
            // the line is finished
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            liveLine = nil
            guard !text.isEmpty else {
                return
            }
            lines.append(CaptionLine(id: liveLineID, speaker: speaker, text: text))
            liveLineID = UUID()
            if lines.count > Self.maxLines {
                lines.removeFirst(lines.count - Self.maxLines)
            }
        case .failed(let message):
            stop()
            errorMessage = message
        }
    }

    // enough for the live captions, nothing is saved
    private static let maxLines = 40

    // the host while talking, the song while music plays
    private var speaker: CaptionSpeaker {
        if mode == .music {
            if nowPlaying == .offAir {
                return .lyrics(track: "Music")
            }
            return .lyrics(track: nowPlaying.title)
        }
        return .host(show: liveShow?.name ?? "Radio Monash")
    }
}
