import AVFoundation
import Speech

/// Owns the on-device speech analyser. Buffers go in through `feed`, and
/// provisional (volatile) and finished (final) text comes out of `updates`.
@available(iOS 26, *)
actor TranscriptionService {
    enum Update: Sendable {
        case volatile(String)
        case final(String)
    }

    nonisolated let updates: AsyncStream<Update>
    private let updatesContinuation: AsyncStream<Update>.Continuation
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    init() {
        (updates, updatesContinuation) = AsyncStream.makeStream(of: Update.self)
    }

    /// Starts the analyser and returns the audio format it wants.
    /// `vocabulary` (show, host and band names) helps it spell them right.
    func start(locale: Locale, vocabulary: [String]) async throws -> AVAudioFormat {
        // Live results as words arrive, with swearing masked: song lyrics in
        // particular would otherwise print slurs on screen.
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [.etiquetteReplacements],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw CaptionError.unsupportedAudio
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if !vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = vocabulary
            try await analyzer.setContext(context)
        }
        try await analyzer.prepareToAnalyze(in: format)

        let (inputSequence, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try await analyzer.start(inputSequence: inputSequence)

        let updates = updatesContinuation
        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    updates.yield(result.isFinal ? .final(text) : .volatile(text))
                }
            } catch {
                // The analyser stopping ends the results; nothing to report.
            }
        }
        self.analyzer = analyzer
        self.input = input
        return format
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        input?.yield(AnalyzerInput(buffer: buffer))
    }

    /// Turns whatever is still provisional into final text, for when the talk stops.
    func flush() async {
        try? await analyzer?.finalize(through: nil)
    }

    func stop() async {
        input?.finish()
        input = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
        await resultsTask?.value
        resultsTask = nil
        updatesContinuation.finish()
    }
}

enum CaptionError: LocalizedError {
    case unsupportedAudio

    var errorDescription: String? {
        switch self {
        case .unsupportedAudio: "Live Captions can't read this stream's audio."
        }
    }
}
