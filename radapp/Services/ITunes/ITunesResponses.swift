import Foundation

// MARK: - JSON

// the json from itunes search
struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesSong]
}

// one result; urls stay strings so one bad entry can't fail the whole response
struct ITunesSong: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let trackViewUrl: String?
    let artworkUrl100: String?
    let trackTimeMillis: Double?
}

// MARK: - Matching

extension ITunesSearchResponse {
    // the result that is the same song
    func bestMatch(title: String, artist: String, duration: TimeInterval?) -> ITunesTrack? {
        let match = TrackName.bestMatch(in: results, title: title, artist: artist, duration: duration) { song in
            // guard exits early if the check fails
            guard let trackName = song.trackName, let artistName = song.artistName else {
                return nil
            }
            // milliseconds to seconds
            let length = song.trackTimeMillis.map { millis in
                millis / 1000
            }
            return SongCredit(title: trackName, artist: artistName, length: length)
        }
        return match?.toTrack()
    }
}

// MARK: - Converting

private extension ITunesSong {
    // the app's own type, nil if anything needed is missing
    func toTrack() -> ITunesTrack? {
        guard let trackId, let trackName, let artistName,
              let trackViewUrl, let pageURL = URL(string: trackViewUrl)
        else {
            return nil
        }
        let thumbnail = artworkUrl100.flatMap(URL.init(string:))
        // 600px if the url can be rewritten, otherwise the 100px one
        var artworkURL = thumbnail
        if let thumbnail, let large = Self.resized(thumbnail, to: 600) {
            artworkURL = large
        }
        return ITunesTrack(
            id: trackId,
            title: trackName,
            artist: artistName,
            trackViewURL: pageURL,
            artworkURL: artworkURL,
            thumbnailURL: thumbnail
        )
    }

    // swaps "100x100" in the url for another size; undocumented, hence the fallback
    static func resized(_ url: URL, to size: Int) -> URL? {
        let string = url.absoluteString
        guard string.contains("100x100") else {
            return nil
        }
        return URL(string: string.replacingOccurrences(of: "100x100", with: "\(size)x\(size)"))
    }
}
