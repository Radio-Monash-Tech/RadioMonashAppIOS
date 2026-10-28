import Foundation

/// Recently played: RadioCult's history plus songs the app saw finish on the
/// live feed.
struct TrackHistory {
    static let limit = 5

    /// Recently played as RadioCult reports it.
    var reported: [PlayedTrack] = []
    private var observed: [PlayedTrack] = []

    /// RadioCult only lists a song in its history a while after it ends, so
    /// the song that just finished would be missing. The live feed moving on
    /// means it finished, so it's added straight away.
    mutating func recordFinished(_ track: NowPlaying) {
        guard track != .offAir, let startedAt = track.startedAt else { return }
        let played = PlayedTrack(
            id: "live-\(Int(startedAt.timeIntervalSince1970))",
            title: track.title,
            artist: track.artist,
            playedAt: startedAt,
            artworkURL: track.artworkURL
        )
        guard !observed.contains(where: { $0.isSamePlay(as: played) }) else { return }
        observed.insert(played, at: 0)
        observed = Array(observed.prefix(Self.limit))
    }

    /// Both lists merged, newest first. When both have a song, RadioCult's
    /// entry wins; the song on air now is left out.
    func recent(excluding nowPlaying: NowPlaying) -> [PlayedTrack] {
        var merged = reported
        for track in observed where !merged.contains(where: { $0.isSamePlay(as: track) }) {
            merged.append(track)
        }
        let playing = nowPlaying.startedAt.map {
            PlayedTrack(id: "", title: nowPlaying.title, artist: nowPlaying.artist, playedAt: $0, artworkURL: nil)
        }
        let recent = merged
            .filter { track in playing.map { !track.isSamePlay(as: $0) } ?? true }
            .sorted { $0.playedAt > $1.playedAt }
            .prefix(Self.limit)
        return Array(recent)
    }
}
