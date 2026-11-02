import Foundation

// what the app hands the widget, saved in the app group; widgets can't reach the player themselves
// nonisolated means not tied to the main thread
nonisolated struct RadioWidgetSnapshot: Codable, Equatable {
    // MARK: - Upcoming show

    // one show in "up next"
    struct UpcomingShow: Codable, Hashable {
        var start: Date
        var title: String
        var hosts: String?
        var isFollowed: Bool
    }

    // MARK: - Contents

    // a show is on, not the playlist
    var isOnAir: Bool
    var isPlaying: Bool
    var isLiked: Bool
    // the show while one is on, otherwise the song
    var title: String
    var subtitle: String?
    var showName: String?
    var showStart: Date?
    var showEnd: Date?
    // the saved cover's file; nil shows the station logo
    var artworkFileName: String?
    var upNext: [UpcomingShow]
    // true dark, false light, nil follows ios
    var isDark: Bool?

    // MARK: - Saving and loading

    static let widgetKind = "RadioWidget"
    private static let storageKey = "radioWidgetSnapshot"

    static func load() -> RadioWidgetSnapshot? {
        // guard exits early if the check fails
        guard let data = AccentChoice.store.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(RadioWidgetSnapshot.self, from: data)
    }

    // false when nothing changed, so the widget isn't reloaded for no reason
    // @discardableResult means callers can ignore the return value
    @discardableResult
    func save() -> Bool {
        guard self != Self.load(), let data = try? JSONEncoder().encode(self) else {
            return false
        }
        AccentChoice.store.set(data, forKey: Self.storageKey)
        return true
    }

    // MARK: - Placeholder

    // shown in the widget gallery and before the app has run
    static let placeholder = RadioWidgetSnapshot(
        isOnAir: false, isPlaying: false, isLiked: false,
        title: "Radio Monash", subtitle: "Default playlist",
        showName: nil, showStart: nil, showEnd: nil,
        artworkFileName: nil, upNext: [], isDark: nil
    )
}
