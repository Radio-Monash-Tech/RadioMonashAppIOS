import Foundation

// A catalogue entry's title, artist credit and length, for comparing against
// what RadioCult reported.
struct SongCredit {
    let title: String
    let artist: String
    let length: TimeInterval?
}

// Reduces titles and artist credits to a comparable form, since RadioCult and
// the music catalogues rarely agree on casing, accents, featured artists or edition tags.
enum TrackName {
    // The candidate that is the same song. When several are (album, single and
    // compilation releases), prefers the one closest to the broadcast length.
    static func bestMatch<Candidate>(
        in candidates: [Candidate],
        title: String,
        artist: String,
        duration: TimeInterval?,
        credit: (Candidate) -> SongCredit?
    ) -> Candidate? {
        let wantedTitle = self.title(title)
        let wantedArtist = primaryArtist(artist)
        guard !wantedTitle.isEmpty, !wantedArtist.isEmpty else { return nil }

        let matches = candidates
            .compactMap { candidate in credit(candidate).map { (candidate, $0) } }
            .filter { isSameSong($0.1, title: wantedTitle, artist: wantedArtist) }
        guard let duration, duration > 0 else { return matches.first?.0 }
        return matches.min {
            ($0.1.length.map { abs($0 - duration) } ?? .infinity) < ($1.1.length.map { abs($0 - duration) } ?? .infinity)
        }?.0
    }

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

    private static func isSameSong(_ credit: SongCredit, title wantedTitle: String, artist wantedArtist: String) -> Bool {
        guard title(credit.title) == wantedTitle else { return false }
        // Either side may list collaborators the other leaves out, so it's
        // enough for one side's lead artist to appear in the other's credit.
        return containsWords(wantedArtist, in: artist(credit.artist))
            || containsWords(primaryArtist(credit.artist), in: artist(wantedArtist))
    }

    // Curly apostrophes are straightened so "Don’t" and "Don't" compare equal.
    private static func folded(_ raw: String) -> String {
        raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "\u{2019}", with: "'")
    }

    // Letters, digits and in-word apostrophes, single-spaced. Apostrophes stay
    // because iTunes can't find "what s up" or "don t think" once they're split.
    private static func words(_ text: String) -> String {
        text.components(separatedBy: wordCharacters.inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'"))
}
