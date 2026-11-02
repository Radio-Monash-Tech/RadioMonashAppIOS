import AVFoundation
import Synchronization

// MARK: - Events

// what the caption pipeline reports back
// nonisolated means not tied to the main thread
nonisolated enum CaptionEvent: Sendable {
    // talk or music changed
    case mode(CaptionMode)
    // words still coming in
    case volatile(String)
    // a finished line
    case final(String)
    // something went wrong, with a message to show
    case failed(String)
}

// MARK: - Engine

// one listening stretch of captions: audio to the classifier, then to speech recognition
// @available limits this to iOS 26 and later
@available(iOS 26, *)
// @unchecked Sendable promises it's thread-safe, the compiler can't check
nonisolated final class CaptionEngine: @unchecked Sendable {
    // decides talk or music
    let classifier = ContentClassifier()
    // caption lyrics as well as talk, can change while running thanks to atomic
    // Atomic can be read and written from several threads safely, without locks
    let includesMusic = Atomic<Bool>(true)
    // apple's speech recognition
    private let service = TranscriptionService()

    // runs until the audio stream ends
    func run(
        audio: AsyncStream<AVAudioPCMBuffer>,
        locale: Locale,
        vocabulary: [String],
        hint: ContentClassifier.StationHint,
        events: AsyncStream<CaptionEvent>.Continuation
    ) async {
        // defer runs when the function exits, however it exits
        defer {
            events.finish()
        }
        // start speech recognition and convert audio to the format it asks for
        let adapter: AudioFormatAdapter
        do {
            let format = try await service.start(locale: locale, vocabulary: vocabulary)
            adapter = AudioFormatAdapter(outputFormat: format)
        } catch {
            events.yield(.failed(error.localizedDescription))
            return
        }

        classifier.setHint(hint)
        events.yield(.mode(classifier.mode))
        let service = service
        classifier.onChange = { mode in
            events.yield(.mode(mode))
            // finish the last words before switching, instead of leaving them grey
            Task {
                await service.flush()
            }
        }

        // pass recognised text on as events
        let forwarding = Task {
            for await update in service.updates {
                switch update {
                case .volatile(let text):
                    events.yield(.volatile(text))
                case .final(let text):
                    events.yield(.final(text))
                }
            }
        }

        // only feed speech recognition talk, or music too if lyrics are wanted
        for await buffer in audio {
            classifier.analyze(buffer)
            let wanted = classifier.mode == .talk || includesMusic.load(ordering: .relaxed)
            if wanted, let converted = adapter.convert(buffer) {
                await service.feed(converted)
            }
        }

        // the audio ended, so wind down
        classifier.onChange = nil
        await service.stop()
        await forwarding.value
    }
}
