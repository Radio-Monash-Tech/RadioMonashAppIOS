import AVFoundation
import SoundAnalysis
import Synchronization

/// What's on air, as far as captions care.
nonisolated enum CaptionMode: String, Sendable {
    case talk, music
}

/// Decides whether the station is playing talk or music, so lyrics can be
/// shown differently and kept out of the transcript. RadioCult's metadata comes first: with nobody presenting
/// (the automated playlist, or a playlist show) it's always music. During a
/// presenter's show Apple's built-in sound classifier listens, and a change
/// only counts once it has held for a moment, so a host talking over a song
/// intro doesn't make captions flicker.
nonisolated final class ContentClassifier: NSObject, SNResultsObserving, @unchecked Sendable {
    enum StationHint: Sendable {
        /// Library tracks with no host: nothing to caption.
        case automated
        /// A presenter's show: talk and music both possible.
        case presenter
    }

    /// Called on the analysing thread when the mode changes.
    var onChange: (@Sendable (CaptionMode) -> Void)?

    // About 1.5 s and 3 s of agreement, with a result every 0.75 s. Captions
    // start quickly and stop slowly, erring towards showing them.
    private static let votesToTalk = 2
    private static let votesToMusic = 4

    private struct State {
        var mode: CaptionMode = .talk
        var hint: StationHint = .presenter
        var talkVotes = 0
        var musicVotes = 0
    }
    private let state = Mutex(State())

    // Only touched from the one task that calls `analyze`.
    private var analyzer: SNAudioStreamAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var framePosition: AVAudioFramePosition = 0

    var mode: CaptionMode { state.withLock { $0.mode } }

    func setHint(_ hint: StationHint) {
        let changed: CaptionMode? = state.withLock { state in
            guard state.hint != hint else { return nil }
            state.hint = hint
            state.talkVotes = 0
            state.musicVotes = 0
            // Automated means music; a show starting usually means talk.
            let mode: CaptionMode = hint == .automated ? .music : .talk
            guard state.mode != mode else { return nil }
            state.mode = mode
            return mode
        }
        if let changed { onChange?(changed) }
    }

    func analyze(_ buffer: AVAudioPCMBuffer) {
        // No point running the model when RadioCult already says it's music.
        guard state.withLock({ $0.hint }) == .presenter else { return }
        if analyzerFormat != buffer.format {
            analyzer = makeAnalyzer(format: buffer.format)
            analyzerFormat = buffer.format
            framePosition = 0
        }
        analyzer?.analyze(buffer, atAudioFramePosition: framePosition)
        framePosition += AVAudioFramePosition(buffer.frameLength)
    }

    private func makeAnalyzer(format: AVAudioFormat) -> SNAudioStreamAnalyzer? {
        guard let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else { return nil }
        request.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 48_000)
        request.overlapFactor = 0.5
        let analyzer = SNAudioStreamAnalyzer(format: format)
        guard (try? analyzer.add(request, withObserver: self)) != nil else { return nil }
        return analyzer
    }

    // MARK: SNResultsObserving

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        func confidence(_ label: String) -> Double {
            result.classification(forIdentifier: label)?.confidence ?? 0
        }
        let speech = confidence("speech")
        let vocals = max(confidence("singing"), confidence("rapping"))
        let music = confidence("music")

        // Speech louder than any vocals is talk, even over a backing track.
        let vote: CaptionMode?
        if speech >= 0.5, speech > vocals {
            vote = .talk
        } else if music >= 0.5 || vocals >= 0.5 {
            vote = .music
        } else {
            vote = nil // silence or noise: no change
        }

        let changed: CaptionMode? = state.withLock { state in
            guard state.hint == .presenter, let vote else { return nil }
            if vote == .talk {
                state.talkVotes += 1
                state.musicVotes = 0
            } else {
                state.musicVotes += 1
                state.talkVotes = 0
            }
            if state.mode == .music, state.talkVotes >= Self.votesToTalk {
                state.mode = .talk
                return .talk
            }
            if state.mode == .talk, state.musicVotes >= Self.votesToMusic {
                state.mode = .music
                return .music
            }
            return nil
        }
        if let changed { onChange?(changed) }
    }
}
