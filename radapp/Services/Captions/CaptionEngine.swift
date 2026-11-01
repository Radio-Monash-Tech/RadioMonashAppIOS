import AVFoundation
import Synchronization

// what the caption pipeline reports back
nonisolated enum CaptionEvent: Sendable {
    case mode(CaptionMode)
    case volatile(String)
    case final(String)
    case failed(String)
}

// one listening stretch of captions: audio to the classifier, then to speech recognition
@available(iOS 26, *)
nonisolated final class CaptionEngine: @unchecked Sendable {
    let classifier = ContentClassifier()
    // caption lyrics as well as talk; can change while running
    let includesMusic = Atomic<Bool>(true)
    private let service = TranscriptionService()

    func run(
        audio: AsyncStream<AVAudioPCMBuffer>,
        locale: Locale,
        vocabulary: [String],
        hint: ContentClassifier.StationHint,
        events: AsyncStream<CaptionEvent>.Continuation
    ) async {
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
