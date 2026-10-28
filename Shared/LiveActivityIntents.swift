import AppIntents

/// Buttons on the Live Activity and Home Screen widget. These intents run
/// inside the app's process, so `perform` reaches the real player through
/// `LiveActivityActions`. `AudioPlaybackIntent` also lets the widget start
/// the stream when the app isn't running.
nonisolated struct TogglePlaybackIntent: LiveActivityIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Radio"

    func perform() async throws -> some IntentResult {
        await LiveActivityActions.togglePlayback()
        return .result()
    }
}

nonisolated struct ToggleLikeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Like Current Track"

    func perform() async throws -> some IntentResult {
        await LiveActivityActions.toggleLike()
        return .result()
    }
}

/// Filled in by the app at launch; left empty in the widget extension. The
/// closures are main-actor so the player and SwiftData are only touched on
/// the main thread, even though intents run in the background.
@MainActor
enum LiveActivityActions {
    static var togglePlayback: @MainActor () -> Void = {}
    static var toggleLike: @MainActor () -> Void = {}
}
