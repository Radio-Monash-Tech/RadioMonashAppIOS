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
    let trackName: String?
    let artistName: String?
    let trackViewUrl: String?
    let artworkUrl100: String?
    let trackTimeMillis: Double?
}

extension ITunesSearchResponse {
    // The result that is the same song. When several are (album, single and
    // compilation releases), prefers the one closest to the broadcast length.
    func bestMatch(title: String, artist: String, duration: TimeInterval?) -> ITunesTrack? {
        let wantedTitle = TrackName.title(title)
        let wantedArtist = TrackName.primaryArtist(artist)
        guard !wantedTitle.isEmpty, !wantedArtist.isEmpty else { return nil }

        let matches = results.filter { $0.matches(title: wantedTitle, artist: wantedArtist) }
        let best = if let duration, duration > 0 {
            matches.min { $0.lengthDifference(from: duration) < $1.lengthDifference(from: duration) }
        } else {
            matches.first
        }
        return best?.toTrack()
    }
}

private extension ITunesSong {
    func matches(title wantedTitle: String, artist wantedArtist: String) -> Bool {
        guard let trackName, let artistName else { return false }
        guard TrackName.title(trackName) == wantedTitle else { return false }
        // Either side may list collaborators the other leaves out, so it's
        // enough for one side's lead artist to appear in the other's credit.
        let credit = TrackName.artist(artistName)
        return TrackName.containsWords(wantedArtist, in: credit)
            || TrackName.containsWords(TrackName.primaryArtist(artistName), in: TrackName.artist(wantedArtist))
    }

    func lengthDifference(from duration: TimeInterval) -> TimeInterval {
        trackTimeMillis.map { abs($0 / 1000 - duration) } ?? .infinity
    }

    func toTrack() -> ITunesTrack? {
        guard let trackName, let artistName,
              let trackViewUrl, let pageURL = URL(string: trackViewUrl) else { return nil }
        let thumbnail = artworkUrl100.flatMap(URL.init(string:))
        return ITunesTrack(
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

// MARK: - Comparing track names

// Reduces titles and artist credits to a comparable form, since RadioCult and
// iTunes rarely agree on casing, accents, featured artists or edition tags.
enum TrackName {
    // The search query: lead artist and bare title, which finds the song
    // more reliably than the full credit with every edition tag.
    static func searchTerm(title: String, artist: String) -> String {
        let title = self.title(title)
        guard !title.isEmpty else { return "" }
        return [primaryArtist(artist), title].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // "Song (feat. X) - 2011 Remaster" becomes "song".
    static func title(_ raw: String) -> String {
        var text = folded(raw)
        text = text.replacing(#/\s*[\(\[][^\)\]]*[\)\]]/#, with: "")
        if let dash = text.range(of: " - ") { text = String(text[..<dash.lowerBound]) }
        text = text.replacing(#/\s+(feat\.?|ft\.?|featuring)\s.*$/#, with: "")
        return words(text)
    }

    // The whole credit, normalised: "Beyoncé & JAY-Z" becomes "beyonce and jay z".
    static func artist(_ raw: String) -> String {
        words(folded(raw).replacingOccurrences(of: "&", with: " and "))
    }

    // The first credited artist: "Kaytranada, H.E.R. feat. X" becomes "kaytranada".
    static func primaryArtist(_ raw: String) -> String {
        let lead = folded(raw)
            .split(separator: #/,|;|\s&\s|\s+x\s+|\s+(feat\.?|ft\.?|featuring|with|vs\.?)\s+/#, maxSplits: 1)
            .first
            .map(String.init) ?? ""
        return artist(lead)
    }

    // Whole-word containment, so "ash" doesn't match "ashnikko".
    static func containsWords(_ needle: String, in haystack: String) -> Bool {
        !needle.isEmpty && " \(haystack) ".contains(" \(needle) ")
    }

    private static func folded(_ raw: String) -> String {
        raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    // Letters and digits only, single-spaced.
    private static func words(_ text: String) -> String {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
