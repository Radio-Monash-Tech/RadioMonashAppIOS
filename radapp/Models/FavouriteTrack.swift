import Foundation
import SwiftData

// a liked song, saved in the database
@Model
final class FavouriteTrack {
    // stops the same song being liked twice
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

    // artist and title with an invisible separator, lowercased
    static func key(title: String, artist: String) -> String {
        "\(artist)\u{1F}\(title)".lowercased()
    }
}

extension PlayedTrack {
    // the key this song would have if liked
    var favouriteKey: String {
        FavouriteTrack.key(title: title, artist: artist)
    }
}
