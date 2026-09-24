import Foundation
import SwiftData

@Model
final class FavouriteTrack {
    @Attribute(.unique) var key: String
    var title: String
    var artist: String
    var artworkURL: URL?
    var showName: String?
    var savedAt: Date

    init(title: String, artist: String, artworkURL: URL?, showName: String?, savedAt: Date = .now) {
        key = Self.key(title: title, artist: artist)
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.showName = showName
        self.savedAt = savedAt
    }

    static func key(title: String, artist: String) -> String {
        "\(artist)\u{1F}\(title)".lowercased()
    }
}

extension PlayedTrack {
    var favouriteKey: String { FavouriteTrack.key(title: title, artist: artist) }
}
