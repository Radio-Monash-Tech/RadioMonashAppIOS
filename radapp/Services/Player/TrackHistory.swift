import Foundation

// recently played: radiocult's history plus songs the app saw finish
struct TrackHistory {
    static let limit = 5

    // recently played as radiocult reports it
    var reported: [PlayedTrack] = []
    // songs the app saw end on the live feed
    private var observed: [PlayedTrack] = []

    // radiocult lists a song a while after it ends, so the one that just finished is added now
    mutating func recordFinished(_ track: NowPlaying) {
        guard track != .offAir, let startedAt = track.startedAt else {
            return
        }
        let played = PlayedTrack(
            id: "live-\(Int(startedAt.timeIntervalSince1970))",
            title: track.title,
            artist: track.artist,
            playedAt: startedAt,
            artworkURL: track.artworkURL
        )
        let alreadyRecorded = observed.contains { other in
            other.isSamePlay(as: played)
        }
        guard !alreadyRecorded else {
            return
        }
        observed.insert(played, at: 0)
        observed = Array(observed.prefix(Self.limit))
    }

    // both lists merged, newest first, radiocult's entry winning, without the song on air
    func recent(excluding nowPlaying: NowPlaying) -> [PlayedTrack] {
        var merged = reported
        for track in observed {
            let alreadyListed = merged.contains { other in
                other.isSamePlay(as: track)
            }
            if !alreadyListed {
                merged.append(track)
            }
        }

        // the song on air, so it can be left out
        var playing: PlayedTrack?
        if let startedAt = nowPlaying.startedAt {
            playing = PlayedTrack(id: "", title: nowPlaying.title, artist: nowPlaying.artist,
                                  playedAt: startedAt, artworkURL: nil)
        }
        let finished = merged.filter { track in
            guard let playing else {
                return true
            }
            return !track.isSamePlay(as: playing)
        }

        let newestFirst = finished.sorted { first, second in
            first.playedAt > second.playedAt
        }
        return Array(newestFirst.prefix(Self.limit))
    }
}
