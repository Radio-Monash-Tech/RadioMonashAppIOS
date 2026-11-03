import Foundation

// MARK: - JSON

// the json from streaming/history/latest-results
struct HistoryResponse: Decodable {
    let success: Bool
    let data: [HistoryEntry]
}

// one played song
struct HistoryEntry: Decodable {
    let playoutStart: String
    let title: String
    let artist: String?
    let artwork: ArtworkVariants?
}

// MARK: - Converting

extension HistoryResponse {
    // turned into the app's own played tracks
    func toPlayedTracks() -> [PlayedTrack] {
        data.map { entry in
            PlayedTrack(
                id: entry.playoutStart,
                title: entry.title,
                artist: entry.artist ?? "Radio Monash",
                playedAt: RadioCultDate.parse(entry.playoutStart) ?? Date(),
                artworkURL: entry.artwork?.best(preferring: ["256x256", "default", "original"])
            )
        }
    }
}
