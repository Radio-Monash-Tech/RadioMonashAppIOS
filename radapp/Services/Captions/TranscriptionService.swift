import AVFoundation
import Speech

// MARK: - Transcription service

// apple's on-device speech recognition: audio in through feed, text out through updates
// @available limits this to iOS 26 and later
@available(iOS 26, *)
actor TranscriptionService {
    // MARK: - State

    // what comes out of the recogniser
    enum Update: Sendable {
        // words still coming in
        case volatile(String)
        // a finished line
        case final(String)
    }

    // text out, read by the engine
    // nonisolated means not tied to the main thread
    nonisolated let updates: AsyncStream<Update>
    // the sending end of updates
    private let updatesContinuation: AsyncStream<Update>.Continuation
    // apple's analyser, nil until started
    private var analyzer: SpeechAnalyzer?
    // audio in, the analyser reads from this
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    // turns results into updates
    private var resultsTask: Task<Void, Never>?

    // MARK: - Init

    // makes the updates stream
    // init sets up a new instance
    init() {
        (updates, updatesContinuation) = AsyncStream.makeStream(of: Update.self)
    }

    // MARK: - Recognising

    // starts recognising and returns the audio format it wants, vocabulary helps spell names
    func start(locale: Locale, vocabulary: [String]) async throws -> AVAudioFormat {
        // live results as words arrive, with swearing masked
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [.etiquetteReplacements],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        // guard exits early if the check fails
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
                // the analyser stopping ends the results, nothing to report
            }
        }
        self.analyzer = analyzer
        self.input = input
        return format
    }

    // sends one chunk to the recogniser
    func feed(_ buffer: AVAudioPCMBuffer) {
        input?.yield(AnalyzerInput(buffer: buffer))
    }

    // turns whatever is still in progress into final text
    func flush() async {
        try? await analyzer?.finalize(through: nil)
    }

    // finishes the last words, then shuts down
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

// MARK: - Errors

// errors captions can show
enum CaptionError: LocalizedError {
    // no audio format the recogniser accepts
    case unsupportedAudio

    // the message shown on screen
    var errorDescription: String? {
        switch self {
        case .unsupportedAudio:
            "Live Captions can't read this stream's audio."
        }
    }
}
