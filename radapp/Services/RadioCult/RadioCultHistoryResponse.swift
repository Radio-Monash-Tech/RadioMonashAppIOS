import Foundation

// Decodable shapes for GET /api/station/:stationId/streaming/history/latest-results,
// plus their mapping into the app's domain models.

struct HistoryResponse: Decodable {
    let success: Bool
    let data: [HistoryEntry]
}

struct HistoryEntry: Decodable {
    let playoutStart: String
    let title: String
    let artist: String?
    let artwork: ArtworkVariants?
}

extension HistoryResponse {
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
