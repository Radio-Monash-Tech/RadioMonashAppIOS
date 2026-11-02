import Foundation

// MARK: - Song credit

// one search result's title, artist and length
struct SongCredit {
    let title: String
    let artist: String
    let length: TimeInterval?
}

// MARK: - Track name

// tidies song titles and artists so radiocult and itunes can be compared
enum TrackName {
    // MARK: - Matching

    // the search result that is the same song, closest to the broadcast length
    static func bestMatch<Candidate>(
        in candidates: [Candidate],
        title: String,
        artist: String,
        duration: TimeInterval?,
        credit: (Candidate) -> SongCredit?
    ) -> Candidate? {
        let wantedTitle = self.title(title)
        let wantedArtist = primaryArtist(artist)
        guard !wantedTitle.isEmpty, !wantedArtist.isEmpty else {
            return nil
        }

        // pair each candidate with its credit, keep only the same song
        let matches = candidates
            .compactMap { candidate -> (candidate: Candidate, songCredit: SongCredit)? in
                guard let songCredit = credit(candidate) else {
                    return nil
                }
                return (candidate, songCredit)
            }
            .filter { match in
                isSameSong(match.songCredit, title: wantedTitle, artist: wantedArtist)
            }

        // no broadcast length to compare, take the first
        guard let duration, duration > 0 else {
            return matches.first?.candidate
        }

        // seconds between a result's length and the broadcast, unknown lengths go last
        func difference(_ songCredit: SongCredit) -> TimeInterval {
            guard let length = songCredit.length else {
                return .infinity
            }
            return abs(length - duration)
        }

        return matches.min { first, second in
            difference(first.songCredit) < difference(second.songCredit)
        }?.candidate
    }

    // MARK: - Cleaning names

    // lead artist and bare title, finds the song better than the full credit
    static func searchTerm(title: String, artist: String) -> String {
        let title = self.title(title)
        guard !title.isEmpty else {
            return ""
        }
        let parts = [primaryArtist(artist), title].filter { part in
            !part.isEmpty
        }
        return parts.joined(separator: " ")
    }

    // "Song (feat. X) - 2011 Remaster" becomes "song"
    static func title(_ raw: String) -> String {
        var text = folded(raw)
        // drop anything in brackets, e.g. (feat. X) or [Live]
        text = text.replacing(#/\s*[\(\[][^\)\]]*[\)\]]/#, with: "")
        // drop everything after " - ", e.g. "- 2011 Remaster"
        if let dash = text.range(of: " - ") {
            text = String(text[..<dash.lowerBound])
        }
        // drop a feat. credit without brackets
        text = text.replacing(#/\s+(feat\.?|ft\.?|featuring)\s.*$/#, with: "")
        return words(text)
    }

    // "Beyoncé & JAY-Z" becomes "beyonce and jay z"
    static func artist(_ raw: String) -> String {
        let withAnd = folded(raw).replacingOccurrences(of: "&", with: " and ")
        return words(withAnd)
    }

    // "Kaytranada, H.E.R. feat. X" becomes "kaytranada"
    static func primaryArtist(_ raw: String) -> String {
        // split once at the first , ; & x feat. ft. featuring with vs.
        let parts = folded(raw).split(
            separator: #/,|;|\s&\s|\s+x\s+|\s+(feat\.?|ft\.?|featuring|with|vs\.?)\s+/#,
            maxSplits: 1
        )
        let lead = parts.first.map { part in
            String(part)
        } ?? ""
        return artist(lead)
    }

    // whole words only, so "ash" doesn't match "ashnikko"
    static func containsWords(_ needle: String, in haystack: String) -> Bool {
        !needle.isEmpty && " \(haystack) ".contains(" \(needle) ")
    }

    // MARK: - Private helpers

    private static func isSameSong(_ credit: SongCredit, title wantedTitle: String, artist wantedArtist: String) -> Bool {
        guard title(credit.title) == wantedTitle else {
            return false
        }
        // either side may leave out collaborators, so one lead artist in the other's credit is enough
        return containsWords(wantedArtist, in: artist(credit.artist))
            || containsWords(primaryArtist(credit.artist), in: artist(wantedArtist))
    }

    // lowercase, no accents, straight apostrophes
    private static func folded(_ raw: String) -> String {
        raw.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .replacingOccurrences(of: "\u{2019}", with: "'")
    }

    // letters, digits and apostrophes, single spaced; itunes can't find "don t" without the apostrophe
    private static func words(_ text: String) -> String {
        text.components(separatedBy: wordCharacters.inverted)
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            }
            .filter { word in
                !word.isEmpty
            }
            .joined(separator: " ")
    }

    // what counts as part of a word
    private static let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'"))
}
