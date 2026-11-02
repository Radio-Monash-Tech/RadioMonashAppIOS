import Foundation

// MARK: - Top shows

extension StatsWindow {
    // the four shows with the most time, grouped by schedule id when known, otherwise by name
    func topShows(in segments: [ListeningSegment]) -> [ListeningStats.ShowTotal] {
        var shows: [String: ListeningStats.ShowTotal] = [:]
        for segment in segments {
            // guard exits early if the check fails
            guard let name = segment.showName else {
                continue
            }
            let key = segment.seriesID ?? name.lowercased()
            let earlier = shows[key]
            shows[key] = ListeningStats.ShowTotal(
                id: key,
                name: name,
                // keep an id found on an earlier segment
                seriesID: segment.seriesID ?? earlier?.seriesID,
                seconds: (earlier?.seconds ?? 0) + segment.overlap(with: interval)
            )
        }
        let mostListened = shows.values.sorted { first, second in
            first.seconds > second.seconds
        }
        return Array(mostListened.prefix(4))
    }
}

// MARK: - Top artists

extension ListeningStats {
    // the three artists with the most likes, ties in alphabetical order
    static func topArtists(from likes: [FavouriteTrack]) -> [ArtistLikes] {
        var artists: [String: ArtistLikes] = [:]
        for like in likes where !like.artist.isEmpty {
            // "Nikau" and "NIKAU" count as one artist
            let key = like.artist.lowercased()
            let earlier = artists[key]
            artists[key] = ArtistLikes(
                name: earlier?.name ?? like.artist,
                count: (earlier?.count ?? 0) + 1
            )
        }
        let mostLiked = artists.values.sorted { first, second in
            if first.count != second.count {
                return first.count > second.count
            }
            return first.name.localizedCompare(second.name) == .orderedAscending
        }
        return Array(mostLiked.prefix(3))
    }
}
