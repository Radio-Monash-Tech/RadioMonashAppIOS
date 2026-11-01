import AVFoundation
import Speech

// apple's on-device speech recognition: audio in through feed, text out through updates
@available(iOS 26, *)
actor TranscriptionService {
    enum Update: Sendable {
        // words still coming in
        case volatile(String)
        // a finished line
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

    // starts recognising and returns the audio format it wants; vocabulary helps spell names
    func start(locale: Locale, vocabulary: [String]) async throws -> AVAudioFormat {
        // live results as words arrive, with swearing masked
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

        // pass each result on as an update
        let updates = updatesContinuation
        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        updates.yield(.final(text))
                    } else {
                        updates.yield(.volatile(text))
                    }
                }
            } catch {
                // the analyser stopping ends the results; nothing to report
            }
        }
        self.analyzer = analyzer
        self.input = input
        return format
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        input?.yield(AnalyzerInput(buffer: buffer))
    }

    // turns whatever is still in progress into final text
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
        case .unsupportedAudio:
            "Live Captions can't read this stream's audio."
        }
    }
}
