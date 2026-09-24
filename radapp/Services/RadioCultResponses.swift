import Foundation

// Decodable shapes for RadioCult API responses, plus their mapping into
// the app's domain models.

// MARK: - Wire format: GET /api/station/:stationId/schedule/live

struct ScheduleLiveResponse: Decodable {
    let success: Bool
    let result: LiveResult
}

struct LiveResult: Decodable {
    let status: LiveStatus
    let metadata: LiveMetadata?
    /// Only populated when `status == .schedule`; RadioCult returns "Off Air"
    /// (a bare string) or a default-playlist object for the other statuses,
    /// so we only attempt to decode it as an `Event` in that case.
    let show: LiveShowEvent?

    private enum CodingKeys: String, CodingKey {
        case status, metadata, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(LiveStatus.self, forKey: .status)
        metadata = try container.decodeIfPresent(LiveMetadata.self, forKey: .metadata)
        show = status == .schedule
            ? try container.decodeIfPresent(LiveShowEvent.self, forKey: .content)
            : nil
    }
}

enum LiveStatus: String, Decodable {
    case schedule, offAir, defaultPlaylist
}

/// The RadioCult "Event" object, trimmed to what the player needs.
struct LiveShowEvent: Decodable {
    let title: String
    let artistIds: [String]?
}

struct LiveMetadata: Decodable {
    let title: String
    let artist: String?
    let album: String?
    let duration: Double?
    let playoutStartUnixTimestamp: Double?
    let artwork: ArtworkVariants?
}

/// RadioCult returns artwork as a map of size label ("32x32", "default",
/// "original", ...) to URL. `best` picks the first available match from a
/// preference list, falling back to whatever is present.
struct ArtworkVariants: Decodable {
    let urls: [String: URL]

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: String].self)
        urls = raw.compactMapValues(URL.init)
    }

    func best(preferring order: [String] = ["512x512", "default", "original"]) -> URL? {
        for key in order {
            if let url = urls[key] { return url }
        }
        return urls.values.first
    }
}

extension ScheduleLiveResponse {
    func toNowPlaying() -> (track: NowPlaying, show: LiveShow?) {
        guard let metadata else { return (.offAir, nil) }
        let track = NowPlaying(
            title: metadata.title,
            artist: metadata.artist ?? "Radio Monash",
            artworkURL: metadata.artwork?.best(),
            startedAt: metadata.playoutStartUnixTimestamp.map(Date.init(timeIntervalSince1970:)),
            duration: metadata.duration
        )
        let show = result.show.map { LiveShow(name: $0.title, host: nil, endsAt: nil) }
        return (track, show)
    }

    private var metadata: LiveMetadata? { result.metadata }
}

// MARK: - Wire format: GET /api/station/:stationId/streaming/history/latest-results

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
        let formatter = ISO8601DateFormatter()
        return data.map { entry in
            PlayedTrack(
                id: entry.playoutStart,
                title: entry.title,
                artist: entry.artist ?? "Radio Monash",
                playedAt: formatter.date(from: entry.playoutStart) ?? Date(),
                artworkURL: entry.artwork?.best(preferring: ["256x256", "default", "original"])
            )
        }
    }
}
