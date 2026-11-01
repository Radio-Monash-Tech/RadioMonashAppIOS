import Foundation
import Speech

// whether live captions can run
enum CaptionAvailability: Equatable {
    case checking
    case unsupported(String)
    case needsDownload
    case downloading(Double)
    case ready
}

// checks for and downloads apple's speech model
@available(iOS 26, *)
enum CaptionModelManager {
    // australian english, or the nearest english the phone supports
    static func locale() async -> Locale? {
        for identifier in ["en_AU", "en_GB", "en_US"] {
            if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier)) {
                return locale
            }
        }
        return nil
    }

    static func availability() async -> (CaptionAvailability, Locale?) {
        guard SpeechTranscriber.isAvailable else {
            return (.unsupported("This iPhone can't run Apple's on-device speech recognition."), nil)
        }
        guard let locale = await locale() else {
            return (.unsupported("On-device speech recognition doesn't support English on this iPhone."), nil)
        }
        switch await AssetInventory.status(forModules: [transcriber(for: locale)]) {
        case .installed:
            return (.ready, locale)
        case .supported, .downloading:
            return (.needsDownload, locale)
        case .unsupported:
            return (.unsupported("On-device speech recognition isn't available on this iPhone."), nil)
        @unknown default:
            return (.unsupported("On-device speech recognition isn't available on this iPhone."), nil)
        }
    }

    // downloads and installs the model, reporting progress from 0 to 1
    static func download(for locale: Locale, progress: @escaping @MainActor (Double) -> Void) async throws {
        let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber(for: locale)])
        // nil means it's already installed
        guard let request else {
            return
        }
        let polling = Task { @MainActor in
            while !Task.isCancelled {
                progress(request.progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer {
            polling.cancel()
        }
        try await request.downloadAndInstall()
    }

    private static func transcriber(for locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    }
}
