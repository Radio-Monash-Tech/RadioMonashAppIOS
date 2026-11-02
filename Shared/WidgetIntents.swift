import AppIntents

// MARK: - Play button

// the widget's play button; runs inside the app so it reaches the real player, even when closed
// nonisolated means not tied to the main thread
nonisolated struct TogglePlaybackIntent: LiveActivityIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Radio"

    func perform() async throws -> some IntentResult {
        await WidgetActions.togglePlayback()
        return .result()
    }
}

// MARK: - Like button

// the widget's like button
nonisolated struct ToggleLikeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Like Current Track"

    func perform() async throws -> some IntentResult {
        await WidgetActions.toggleLike()
        return .result()
    }
}

// MARK: - App actions

// filled in by the app at launch, empty in the widget; main actor so the player is only touched there
// @MainActor runs this on the main thread
@MainActor
enum WidgetActions {
    static var togglePlayback: @MainActor () -> Void = {}
    static var toggleLike: @MainActor () -> Void = {}
}
