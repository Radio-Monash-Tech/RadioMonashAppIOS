import AppIntents

// the widget's play button; runs inside the app so it reaches the real player, even when closed
nonisolated struct TogglePlaybackIntent: LiveActivityIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Radio"

    func perform() async throws -> some IntentResult {
        await WidgetActions.togglePlayback()
        return .result()
    }
}

// the widget's like button
nonisolated struct ToggleLikeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Like Current Track"

    func perform() async throws -> some IntentResult {
        await WidgetActions.toggleLike()
        return .result()
    }
}

// filled in by the app at launch, empty in the widget; main actor so the player is only touched there
@MainActor
enum WidgetActions {
    static var togglePlayback: @MainActor () -> Void = {}
    static var toggleLike: @MainActor () -> Void = {}
}
