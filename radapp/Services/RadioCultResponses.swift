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

    private enum CodingKeys: String, CodingKey {
        case title, artist, album, duration, playoutStartUnixTimestamp, artwork
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
    }
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
        let show = result.show.map { LiveShow(name: $0.title, host: nil, endsAt: nil) }
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

// MARK: - Wire format: GET /api/station/:stationId/schedule

struct ScheduleResponse: Decodable {
    let schedules: [ScheduleEvent]
}

struct ScheduleEvent: Decodable {
    let id: String
    let originalId: String?
    let title: String
    let startDateUtc: String
    let endDateUtc: String
    let description: TipTapNode?
    let artists: [ScheduleArtist]

    private enum CodingKeys: String, CodingKey {
        case id, originalId, title, startDateUtc, endDateUtc, description, artists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        originalId = try container.decodeIfPresent(String.self, forKey: .originalId)
        title = try container.decode(String.self, forKey: .title)
        startDateUtc = try container.decode(String.self, forKey: .startDateUtc)
        endDateUtc = try container.decode(String.self, forKey: .endDateUtc)
        description = try? container.decodeIfPresent(TipTapNode.self, forKey: .description)
        artists = (try? container.decodeIfPresent([ScheduleArtist].self, forKey: .artists)) ?? []
    }
}

struct ScheduleArtist: Decodable {
    let id: String
    let name: String
}

struct TipTapNode: Decodable {
    let type: String
    let text: String?
    let marks: [TipTapMark]?
    let content: [TipTapNode]?
}

struct TipTapMark: Decodable {
    struct Attributes: Decodable {
        let href: String?
    }

    let type: String
    let attrs: Attributes?
}

extension TipTapNode {
    var attributedText: AttributedString {
        switch type {
        case "text":
            var run = AttributedString(text ?? "")
            var intent = InlinePresentationIntent()
            for mark in marks ?? [] {
                switch mark.type {
                case "bold": intent.insert(.stronglyEmphasized)
                case "italic": intent.insert(.emphasized)
                case "code": intent.insert(.code)
                case "strike": intent.insert(.strikethrough)
                case "link": run.link = mark.attrs?.href.flatMap(URL.init(string:))
                default: break
                }
            }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            return run
        case "hardBreak":
            return AttributedString("\n")
        case "listItem":
            return AttributedString("• ") + children(separatedBy: "\n")
        case "doc", "blockquote":
            return children(separatedBy: "\n\n")
        case "bulletList", "orderedList":
            return children(separatedBy: "\n")
        default:
            return children(separatedBy: "")
        }
    }

    private func children(separatedBy separator: String) -> AttributedString {
        let parts = (content ?? []).map(\.attributedText).filter { !$0.characters.isEmpty }
        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 { result += AttributedString(separator) }
            result += part
        }
        return result
    }
}

extension ScheduleResponse {
    func toScheduledShows() -> [ScheduledShow] {
        schedules.compactMap { event in
            guard let start = RadioCultDate.parse(event.startDateUtc),
                  let end = RadioCultDate.parse(event.endDateUtc),
                  end > start
            else { return nil }

            let summary = event.description?.attributedText
            let series = ShowSeries(
                id: event.originalId ?? event.id,
                title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
                hosts: event.artists.map(\.name),
                summary: summary.flatMap { $0.characters.isEmpty ? nil : $0 }
            )
            return ScheduledShow(id: event.id, series: series, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }
}
