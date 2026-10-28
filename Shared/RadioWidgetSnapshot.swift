import Foundation

/// What the app hands the Home Screen widget, saved in the App Group.
/// Widgets can't reach the player or download images while rendering, so the
/// app keeps this up to date and saves the cover as a file.
nonisolated struct RadioWidgetSnapshot: Codable, Equatable {
    struct UpcomingShow: Codable, Hashable {
        var start: Date
        var title: String
        var hosts: String?
        var isFollowed: Bool
    }

    /// A show is on air, rather than the station's playlist.
    var isOnAir: Bool
    var isPlaying: Bool
    var isLiked: Bool
    /// The show while one is on air, otherwise the song, as in the app.
    var title: String
    var subtitle: String?
    var showName: String?
    var showStart: Date?
    var showEnd: Date?
    /// Cover saved in `WidgetArtwork.directory`. `nil` shows the station logo.
    var artworkFileName: String?
    var upNext: [UpcomingShow]
    /// The app's Appearance setting: `true` dark, `false` light, `nil` follows iOS.
    var isDark: Bool?

    static let widgetKind = "RadioWidget"
    private static let storageKey = "radioWidgetSnapshot"

    static func load() -> RadioWidgetSnapshot? {
        guard let data = AccentChoice.store.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(RadioWidgetSnapshot.self, from: data)
    }

    /// Returns `false` when nothing changed, so the widget isn't reloaded for no reason.
    @discardableResult
    func save() -> Bool {
        guard self != Self.load(), let data = try? JSONEncoder().encode(self) else { return false }
        AccentChoice.store.set(data, forKey: Self.storageKey)
        return true
    }

    /// Shown in the widget gallery and before the app has run.
    static let placeholder = RadioWidgetSnapshot(
        isOnAir: false, isPlaying: false, isLiked: false,
        title: "Radio Monash", subtitle: "Default playlist",
        showName: nil, showStart: nil, showEnd: nil,
        artworkFileName: nil, upNext: [], isDark: nil
    )
}
