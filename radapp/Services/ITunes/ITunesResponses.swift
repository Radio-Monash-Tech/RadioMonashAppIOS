import Foundation

// Decodable shapes for the iTunes Search API, plus picking which result is
// actually the song RadioCult reported.

// MARK: - Wire format: GET https://itunes.apple.com/search?entity=song

struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesSong]
}

// URLs stay as strings so one malformed entry can't fail the whole response.
struct ITunesSong: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let trackViewUrl: String?
    let artworkUrl100: String?
    let trackTimeMillis: Double?
}

extension ITunesSearchResponse {
    func bestMatch(title: String, artist: String, duration: TimeInterval?) -> ITunesTrack? {
        TrackName.bestMatch(in: results, title: title, artist: artist, duration: duration) { song in
            guard let trackName = song.trackName, let artistName = song.artistName else { return nil }
            return SongCredit(title: trackName, artist: artistName, length: song.trackTimeMillis.map { $0 / 1000 })
        }?.toTrack()
    }
}

private extension ITunesSong {
    func toTrack() -> ITunesTrack? {
        guard let trackId, let trackName, let artistName,
              let trackViewUrl, let pageURL = URL(string: trackViewUrl) else { return nil }
        let thumbnail = artworkUrl100.flatMap(URL.init(string:))
        return ITunesTrack(
            id: trackId,
            title: trackName,
            artist: artistName,
            trackViewURL: pageURL,
            artworkURL: thumbnail.flatMap { Self.resized($0, to: 600) } ?? thumbnail,
            thumbnailURL: thumbnail
        )
    }

    // iTunes artwork URLs end in e.g. `100x100bb.jpg`, and the CDN serves any
    // size swapped in. Undocumented but long-standing, hence the 100px fallback.
    static func resized(_ url: URL, to size: Int) -> URL? {
        let string = url.absoluteString
        guard string.contains("100x100") else { return nil }
        return URL(string: string.replacingOccurrences(of: "100x100", with: "\(size)x\(size)"))
    }
}
