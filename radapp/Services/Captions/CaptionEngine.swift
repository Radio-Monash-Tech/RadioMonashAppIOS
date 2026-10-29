import AVFoundation
import Synchronization

/// What the caption pipeline reports back.
nonisolated enum CaptionEvent: Sendable {
    case mode(CaptionMode)
    case volatile(String)
    case final(String)
    case failed(String)
}

/// The caption pipeline for one listening stretch: tapped audio goes to the
/// classifier, then on to the speech analyser (during songs too, if lyrics
/// are wanted). Runs off the main thread; everything it learns comes out
/// as `CaptionEvent`s.
@available(iOS 26, *)
nonisolated final class CaptionEngine: @unchecked Sendable {
    let classifier = ContentClassifier()
    /// Caption sung lyrics as well as talk. Can change while running.
    let includesMusic = Atomic<Bool>(true)
    private let service = TranscriptionService()

    func run(
        audio: AsyncStream<AVAudioPCMBuffer>,
        locale: Locale,
        vocabulary: [String],
        hint: ContentClassifier.StationHint,
        events: AsyncStream<CaptionEvent>.Continuation
    ) async {
        defer { events.finish() }
        let adapter: AudioFormatAdapter
        do {
            adapter = AudioFormatAdapter(outputFormat: try await service.start(locale: locale, vocabulary: vocabulary))
        } catch {
            events.yield(.failed(error.localizedDescription))
            return
        }

        classifier.setHint(hint)
        events.yield(.mode(classifier.mode))
        let service = service
        classifier.onChange = { mode in
            events.yield(.mode(mode))
            // Settle the last words before the switch, rather than leaving them grey.
            Task { await service.flush() }
        }

        let forwarding = Task {
            for await update in service.updates {
                switch update {
                case .volatile(let text): events.yield(.volatile(text))
                case .final(let text): events.yield(.final(text))
                }
            }
        }

        for await buffer in audio {
            classifier.analyze(buffer)
            let wanted = classifier.mode == .talk || includesMusic.load(ordering: .relaxed)
            if wanted, let converted = adapter.convert(buffer) {
                await service.feed(converted)
            }
        }

        classifier.onChange = nil
        await service.stop()
        await forwarding.value
    }
}
