import AVFoundation
import Synchronization
import Observation

/// The one place the caption UI reads from: whether captions can run, are
/// on, and what they currently say. Starts the pipeline while captions are
/// on and the radio is playing, and stops it otherwise, so nothing runs
/// (or drains the battery) when it isn't needed.
@MainActor
@Observable
final class CaptionCoordinator {
    private(set) var availability: CaptionAvailability = .checking
    /// The CC switch, remembered between launches.
    var isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled) {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.enabled)
            refresh()
        }
    }
    /// Caption song lyrics too, not just talk.
    var captionsMusic = UserDefaults.standard.object(forKey: Keys.music) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(captionsMusic, forKey: Keys.music)
            setIncludesMusic?(captionsMusic)
        }
    }
    var textSize = CaptionTextSize(rawValue: UserDefaults.standard.string(forKey: Keys.textSize) ?? "") ?? .system {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: Keys.textSize) }
    }
    /// Whether the privacy explainer has been seen, shown before captions first turn on.
    private(set) var hasSeenIntro = UserDefaults.standard.bool(forKey: Keys.seenIntro)

    /// Talk or music while the pipeline runs; nil while it's starting or stopped.
    private(set) var mode: CaptionMode?
    private(set) var isRunning = false
    /// Finished caption lines, oldest first.
    private(set) var lines: [CaptionLine] = []
    /// The line still being said or sung; the analyser may change its words.
    private(set) var liveLine: CaptionLine?
    private(set) var errorMessage: String?
    private(set) var isPlaying = false

    @ObservationIgnored private let bridge = AudioTapBridge()
    @ObservationIgnored private weak var playerItem: AVPlayerItem?
    @ObservationIgnored private var locale: Locale?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private var setHint: ((ContentClassifier.StationHint) -> Void)?
    @ObservationIgnored private var setIncludesMusic: ((Bool) -> Void)?
    /// Kept while a line is live and reused when it's finished, so the line
    /// doesn't jump as it settles.
    @ObservationIgnored private var liveLineID = UUID()
    @ObservationIgnored private var liveShow: LiveShow?
    @ObservationIgnored private var nowPlaying: NowPlaying = .offAir
    @ObservationIgnored private var vocabulary: [String] = []

    private enum Keys {
        static let enabled = "captionsEnabled"
        static let textSize = "captionTextSize"
        static let music = "captionsMusic"
        static let seenIntro = "captionsSeenIntro"
    }

    init() {
        Task { await checkAvailability() }
    }

    /// The lines (and the live one) grouped by speaker, for display.
    var groups: [CaptionGroup] {
        var result: [CaptionGroup] = []
        for line in lines + (liveLine.map { [$0] } ?? []) {
            if let last = result.last, last.speaker == line.speaker {
                result[result.count - 1].lines.append(line)
            } else {
                result.append(CaptionGroup(id: line.id, speaker: line.speaker, lines: [line]))
            }
        }
        return result
    }

    /// The CC button shows unless this phone can't do captions at all.
    var isSupported: Bool {
        switch availability {
        case .checking, .unsupported: false
        default: true
        }
    }

    /// The explainer (and model download) comes before captions first turn on.
    var needsSetup: Bool {
        !hasSeenIntro || availability == .needsDownload
    }

    func finishSetup() {
        hasSeenIntro = true
        UserDefaults.standard.set(true, forKey: Keys.seenIntro)
        isEnabled = true
    }

    // MARK: Model

    func checkAvailability() async {
        guard #available(iOS 26, *) else {
            availability = .unsupported("Live Captions need iOS 26 or later.")
            return
        }
        let (availability, locale) = await CaptionModelManager.availability()
        self.availability = availability
        self.locale = locale
        refresh()
    }

    func downloadModel() async {
        guard #available(iOS 26, *), let locale else { return }
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

    // MARK: Player events

    /// Called just before a new connection plays. The tap goes on now, even
    /// with captions off, because it only works if it's in place before
    /// playback starts. It sits idle until captions run.
    func playerItemReady(_ item: AVPlayerItem) {
        guard item !== playerItem else { return }
        // A reconnect brings a new item; the pipeline has to move to it.
        stop()
        playerItem = item
        // Skipped where captions can never run. While the check is still
        // going at launch, install anyway: the idle tap costs next to nothing.
        if #available(iOS 26, *), isSupported || availability == .checking {
            bridge.install(on: item)
        }
        refresh()
    }

    func playbackChanged(isPlaying: Bool) {
        self.isPlaying = isPlaying
        refresh()
    }

    /// RadioCult's view of what's on: whether a presenter is on air, and the track.
    func stationChanged(liveShow: LiveShow?, nowPlaying: NowPlaying, vocabulary: [String]) {
        self.liveShow = liveShow
        self.nowPlaying = nowPlaying
        self.vocabulary = vocabulary
        setHint?(hint)
    }

    /// With no presenter on air there's nobody to caption.
    private var hint: ContentClassifier.StationHint {
        liveShow == nil ? .automated : .presenter
    }

    // MARK: Pipeline

    private func refresh() {
        let shouldRun = isEnabled && availability == .ready && isPlaying && playerItem != nil
        if shouldRun, runTask == nil {
            start()
        } else if !shouldRun, runTask != nil {
            stop()
        }
    }

    private func start() {
        guard #available(iOS 26, *), let item = playerItem, let locale else { return }
        guard bridge.isInstalled(on: item), let audio = bridge.startCapture() else {
            // Only after captions were set up mid-listen on a stream that began without the tap.
            errorMessage = "Captions start the next time you press play."
            return
        }
        let engine = CaptionEngine()
        engine.includesMusic.store(captionsMusic, ordering: .relaxed)
        setHint = { engine.classifier.setHint($0) }
        setIncludesMusic = { engine.includesMusic.store($0, ordering: .relaxed) }
        let (events, continuation) = AsyncStream.makeStream(of: CaptionEvent.self)
        let hint = hint
        let vocabulary = vocabulary
        isRunning = true
        errorMessage = nil
        lines = []
        liveLine = nil

        Task.detached(priority: .userInitiated) {
            await engine.run(audio: audio, locale: locale, vocabulary: vocabulary, hint: hint, events: continuation)
        }
        runTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    private func stop() {
        bridge.stopCapture() // ends the audio, which winds down the engine
        runTask?.cancel()
        runTask = nil
        setHint = nil
        setIncludesMusic = nil
        isRunning = false
        mode = nil
        // Finished lines stay readable after pausing; only the live one goes.
        liveLine = nil
    }

    private func handle(_ event: CaptionEvent) {
        switch event {
        case .mode(let newMode):
            guard newMode != mode else { return }
            mode = newMode
        case .volatile(let text):
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            liveLine = text.isEmpty ? nil : CaptionLine(id: liveLineID, speaker: speaker, text: text)
        case .final(let text):
            let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            liveLine = nil
            guard !text.isEmpty else { return }
            lines.append(CaptionLine(id: liveLineID, speaker: speaker, text: text))
            liveLineID = UUID()
            if lines.count > Self.maxLines { lines.removeFirst(lines.count - Self.maxLines) }
        case .failed(let message):
            stop()
            errorMessage = message
        }
    }

    /// Enough to scroll back a little in Transcript. Nothing is saved to the iPhone.
    private static let maxLines = 40

    /// The show's host while talking, the song while music plays.
    private var speaker: CaptionSpeaker {
        if mode == .music {
            return .lyrics(track: nowPlaying == .offAir ? "Music" : nowPlaying.title)
        }
        return .host(show: liveShow?.name ?? "Radio Monash")
    }
}
