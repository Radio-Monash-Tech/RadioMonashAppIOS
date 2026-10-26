import Foundation

// A song found in the iTunes catalogue that matches a RadioCult track.
struct ITunesTrack: Equatable {
    let id: Int
    let title: String
    let artist: String
    // The song's Apple Music page.
    let trackViewURL: URL
    // 600px artwork, rewritten from the 100px URL iTunes documents.
    let artworkURL: URL?
    // The documented 100px artwork, for when the rewritten URL fails to load.
    let thumbnailURL: URL?

    // Song.link's page for the song, listing it on every streaming service.
    // Its API is retired, but these public pages still resolve from an iTunes ID.
    var songLinkURL: URL { URL(string: "https://song.link/i/\(id)")! }
}
