import Foundation

// A song found in the iTunes catalogue that matches a RadioCult track.
struct ITunesTrack: Equatable {
    let title: String
    let artist: String
    // The song's Apple Music page; also the input Song.link needs.
    let trackViewURL: URL
    // 600px artwork, rewritten from the 100px URL iTunes documents.
    let artworkURL: URL?
    // The documented 100px artwork, for when the rewritten URL fails to load.
    let thumbnailURL: URL?
}
