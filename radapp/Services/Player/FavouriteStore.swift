import Foundation
import SwiftData

/// Liked songs, kept in SwiftData.
struct FavouriteStore {
    let context: ModelContext

    func contains(title: String, artist: String) -> Bool {
        favourite(key: FavouriteTrack.key(title: title, artist: artist)) != nil
    }

    func toggle(title: String, artist: String, artworkURL: URL?, showName: String?) {
        if let existing = favourite(key: FavouriteTrack.key(title: title, artist: artist)) {
            context.delete(existing)
        } else {
            context.insert(FavouriteTrack(title: title, artist: artist, artworkURL: artworkURL, showName: showName))
        }
        try? context.save()
    }

    func remove(_ track: FavouriteTrack) {
        context.delete(track)
        try? context.save()
    }

    private func favourite(key: String) -> FavouriteTrack? {
        var descriptor = FetchDescriptor<FavouriteTrack>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
