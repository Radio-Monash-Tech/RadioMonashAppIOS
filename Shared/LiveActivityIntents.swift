import AppIntents

/// Buttons on the Live Activity. `LiveActivityIntent`s run inside the app's
/// process, so `perform` reaches the real player through `LiveActivityActions`.
nonisolated struct TogglePlaybackIntent: LiveActivityIntent {
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

/// Filled in by the app at launch; left empty in the widget extension.
@MainActor
enum LiveActivityActions {
    static var togglePlayback: () -> Void = {}
    static var toggleLike: () -> Void = {}
}
