import Foundation
import Speech

// MARK: - Availability

// whether live captions can run
enum CaptionAvailability: Equatable {
    // still finding out
    case checking
    // can never run here, with the reason
    case unsupported(String)
    // supported, but the model isn't downloaded
    case needsDownload
    // download progress from 0 to 1
    case downloading(Double)
    // installed, captions can run
    case ready
}

// MARK: - Model manager

// checks for and downloads apple's speech model
// @available limits this to iOS 26 and later
@available(iOS 26, *)
enum CaptionModelManager {
    // australian english, or the nearest english the phone supports
    static func locale() async -> Locale? {
        // look for these languages when speaking
        for identifier in ["en_AU", "en_GB", "en_US"] {
            if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: identifier)) {
                return locale
            }
        }
        return nil
    }
    
    // rail guard to check on the availability of SpeechTranscriber on a device
    static func availability() async -> (CaptionAvailability, Locale?) {
        // guard exits early if the check fails
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
    // @MainActor runs this on the main thread, @escaping means the closure is kept and called later
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
        // defer runs when the function exits, however it exits
        defer {
            polling.cancel()
        }
        try await request.downloadAndInstall()
    }

    // describes which model to check or download
    private static func transcriber(for locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    }
}
