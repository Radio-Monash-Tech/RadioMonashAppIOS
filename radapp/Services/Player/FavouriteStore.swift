import Foundation
import SwiftData

// liked songs in the database
struct FavouriteStore {
    let context: ModelContext

    func contains(title: String, artist: String) -> Bool {
        favourite(key: FavouriteTrack.key(title: title, artist: artist)) != nil
    }

    // likes it, or unlikes it if already liked
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

    // the liked song with this key, if any
    private func favourite(key: String) -> FavouriteTrack? {
        // #Predicate macro, a filter SwiftData can run
        var descriptor = FetchDescriptor<FavouriteTrack>(predicate: #Predicate { track in
            track.key == key
        })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
