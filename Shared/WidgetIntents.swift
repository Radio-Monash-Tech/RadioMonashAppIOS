import AppIntents

/// The Home Screen widget's Play and Like buttons. `LiveActivityIntent` makes
/// them run inside the app's process (the app has no Live Activity; the
/// protocol is only used for where it runs), so `perform` reaches the real
/// player through `WidgetActions`. `AudioPlaybackIntent` also lets Play start
/// the stream when the app isn't running.
nonisolated struct TogglePlaybackIntent: LiveActivityIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause Radio"

    func perform() async throws -> some IntentResult {
        await WidgetActions.togglePlayback()
        return .result()
    }
}

nonisolated struct ToggleLikeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Like Current Track"

    func perform() async throws -> some IntentResult {
        await WidgetActions.toggleLike()
        return .result()
    }
}

/// Filled in by the app at launch; left empty in the widget extension. The
/// closures are main-actor so the player and SwiftData are only touched on
/// the main thread, even though intents run in the background.
@MainActor
enum WidgetActions {
    static var togglePlayback: @MainActor () -> Void = {}
    static var toggleLike: @MainActor () -> Void = {}
}
