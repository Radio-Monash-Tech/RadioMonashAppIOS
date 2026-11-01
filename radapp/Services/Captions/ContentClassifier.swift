import AVFoundation
import SoundAnalysis
import Synchronization

// talk or music, as far as captions care
nonisolated enum CaptionMode: String, Sendable {
    case talk, music
}

// decides talk or music; a change only counts once it holds, so captions don't flicker
nonisolated final class ContentClassifier: NSObject, SNResultsObserving, @unchecked Sendable {
    enum StationHint: Sendable {
        // the automated playlist, no host: always music
        case automated
        // a presenter's show: talk and music both possible
        case presenter
    }

    // called on the analysing thread when the mode changes
    var onChange: (@Sendable (CaptionMode) -> Void)?

    // about 1.5 s and 3 s of agreement; captions start quickly and stop slowly
    private static let votesToTalk = 2
    private static let votesToMusic = 4

    private struct State {
        var mode: CaptionMode = .talk
        var hint: StationHint = .presenter
        var talkVotes = 0
        var musicVotes = 0
    }
    // locked, since two threads use it
    private let state = Mutex(State())

    // only used from the one task that calls analyze
    private var analyzer: SNAudioStreamAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var framePosition: AVAudioFramePosition = 0

    var mode: CaptionMode {
        state.withLock { state in
            state.mode
        }
    }

    func setHint(_ hint: StationHint) {
        let changed: CaptionMode? = state.withLock { state in
            guard state.hint != hint else {
                return nil
            }
            state.hint = hint
            state.talkVotes = 0
            state.musicVotes = 0
            // automated means music; a show starting usually means talk
            let mode: CaptionMode
            if hint == .automated {
                mode = .music
            } else {
                mode = .talk
            }
            guard state.mode != mode else {
                return nil
            }
            state.mode = mode
            return mode
        }
        if let changed {
            onChange?(changed)
        }
    }

    func analyze(_ buffer: AVAudioPCMBuffer) {
        // no point listening when radiocult already says it's music
        let hint = state.withLock { state in
            state.hint
        }
        guard hint == .presenter else {
            return
        }
        // a new analyser if the audio format changes
        if analyzerFormat != buffer.format {
            analyzer = makeAnalyzer(format: buffer.format)
            analyzerFormat = buffer.format
            framePosition = 0
        }
        analyzer?.analyze(buffer, atAudioFramePosition: framePosition)
        framePosition += AVAudioFramePosition(buffer.frameLength)
    }

    // apple's built-in sound classifier, a result every 0.75 s
    private func makeAnalyzer(format: AVAudioFormat) -> SNAudioStreamAnalyzer? {
        guard let request = try? SNClassifySoundRequest(classifierIdentifier: .version1) else {
            return nil
        }
        request.windowDuration = CMTime(seconds: 1.5, preferredTimescale: 48_000)
        request.overlapFactor = 0.5
        let analyzer = SNAudioStreamAnalyzer(format: format)
        guard (try? analyzer.add(request, withObserver: self)) != nil else {
            return nil
        }
        return analyzer
    }

    // each classifier result is one vote for talk or music
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else {
            return
        }
        func confidence(_ label: String) -> Double {
            result.classification(forIdentifier: label)?.confidence ?? 0
        }
        let speech = confidence("speech")
        let vocals = max(confidence("singing"), confidence("rapping"))
        let music = confidence("music")

        // speech louder than any vocals is talk, even over a backing track
        let vote: CaptionMode?
        if speech >= 0.5, speech > vocals {
            vote = .talk
        } else if music >= 0.5 || vocals >= 0.5 {
            vote = .music
        } else {
            // silence or noise: no change
            vote = nil
        }

        let changed: CaptionMode? = state.withLock { state in
            guard state.hint == .presenter, let vote else {
                return nil
            }
            if vote == .talk {
                state.talkVotes += 1
                state.musicVotes = 0
            } else {
                state.musicVotes += 1
                state.talkVotes = 0
            }
            // enough votes in a row switches the mode
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
        if let changed {
            onChange?(changed)
        }
    }
}
