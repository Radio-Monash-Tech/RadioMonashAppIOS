import Foundation

// Decodable shapes for GET /api/station/:stationId/schedule/live, plus their
// mapping into the app's domain models.

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
    let media: Media?

    struct Media: Decodable {
        /// `live` for a presenter broadcasting in, `playlist` for library tracks;
        /// other values are pre-recorded.
        let type: String?
    }
}

struct LiveMetadata: Decodable {
    let title: String
    let artist: String?
    let album: String?
    let duration: Double?
    let playoutStartUnixTimestamp: Double?
    let artwork: ArtworkVariants?
    /// Set only when the station's automated playlist is playing a library track.
    let trackId: String?

    private enum CodingKeys: String, CodingKey {
        case title, artist, album, duration, playoutStartUnixTimestamp, artwork, trackId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        // Live shows report `"duration": "unknown"` rather than a number.
        duration = try? container.decodeIfPresent(Double.self, forKey: .duration)
        playoutStartUnixTimestamp = try container.decodeIfPresent(Double.self, forKey: .playoutStartUnixTimestamp)
        artwork = try container.decodeIfPresent(ArtworkVariants.self, forKey: .artwork)
        trackId = try? container.decodeIfPresent(String.self, forKey: .trackId)
    }
}

extension ScheduleLiveResponse {
    func toNowPlaying() -> (track: NowPlaying, show: LiveShow?) {
        let show = onAirShow.map { LiveShow(name: $0.title, host: nil, endsAt: nil) }
        // During a live show the stream sends either nothing or the show's
        // own name with no artist; neither is a real track, so keep only the show.
        guard let metadata, show == nil || metadata.artist != nil else { return (.offAir, show) }
        let track = NowPlaying(
            title: metadata.title,
            artist: metadata.artist ?? "Radio Monash",
            artworkURL: metadata.artwork?.best(),
            startedAt: metadata.playoutStartUnixTimestamp.map(Date.init(timeIntervalSince1970:)),
            duration: metadata.duration
        )
        return (track, show)
    }

    private var metadata: LiveMetadata? { result.metadata }

    /// RadioCult reports a show from its scheduled start, but a live slot isn't on air
    /// until the presenter connects; until then the playlist keeps playing library tracks.
    /// A playlist show has no presenter at all, just library tracks with their covers,
    /// so it plays like music, as on the website.
    private var onAirShow: LiveShowEvent? {
        guard let show = result.show else { return nil }
        if show.media?.type == "playlist" { return nil }
        let awaitingPresenter = show.media?.type == "live" && metadata?.trackId != nil
        return awaitingPresenter ? nil : show
    }
}
