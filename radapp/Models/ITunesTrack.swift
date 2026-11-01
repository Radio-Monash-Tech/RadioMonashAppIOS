import Foundation

// a song found on itunes that matches the one radiocult named
struct ITunesTrack: Equatable {
    let id: Int
    let title: String
    let artist: String
    // the song's apple music page
    let trackViewURL: URL
    // 600px artwork, rewritten from itunes' 100px url
    let artworkURL: URL?
    // the 100px artwork, if the 600px one fails
    let thumbnailURL: URL?

    // song.link's page listing the song on every streaming service
    var songLinkURL: URL {
        URL(string: "https://song.link/i/\(id)")!
    }
}
