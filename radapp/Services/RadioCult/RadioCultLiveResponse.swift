import Foundation

// the json from schedule/live
struct ScheduleLiveResponse: Decodable {
    let success: Bool
    let result: LiveResult
}

struct LiveResult: Decodable {
    let status: LiveStatus
    let metadata: LiveMetadata?
    // only read when a show is scheduled; otherwise radiocult sends a plain string
    let show: LiveShowEvent?

    private enum CodingKeys: String, CodingKey {
        case status, metadata, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(LiveStatus.self, forKey: .status)
        metadata = try container.decodeIfPresent(LiveMetadata.self, forKey: .metadata)
        if status == .schedule {
            show = try container.decodeIfPresent(LiveShowEvent.self, forKey: .content)
        } else {
            show = nil
        }
    }
}

enum LiveStatus: String, Decodable {
    case schedule, offAir, defaultPlaylist
}

// radiocult's show, cut down to what the player needs
struct LiveShowEvent: Decodable {
    let title: String
    let artistIds: [String]?
    let media: Media?

    struct Media: Decodable {
        // "live" for a presenter, "playlist" for library songs, anything else is pre-recorded
        let type: String?
    }
}

// the song playing
struct LiveMetadata: Decodable {
    let title: String
    let artist: String?
    let album: String?
    let duration: Double?
    let playoutStartUnixTimestamp: Double?
    let artwork: ArtworkVariants?
    // only set when the automated playlist plays a library song
    let trackId: String?

    private enum CodingKeys: String, CodingKey {
        case title, artist, album, duration, playoutStartUnixTimestamp, artwork, trackId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        // live shows send "unknown" instead of a number
        duration = try? container.decodeIfPresent(Double.self, forKey: .duration)
        playoutStartUnixTimestamp = try container.decodeIfPresent(Double.self, forKey: .playoutStartUnixTimestamp)
        artwork = try container.decodeIfPresent(ArtworkVariants.self, forKey: .artwork)
        trackId = try? container.decodeIfPresent(String.self, forKey: .trackId)
    }
}

extension ScheduleLiveResponse {
    // the song and show, in the app's own types
    func toNowPlaying() -> (track: NowPlaying, show: LiveShow?) {
        var show: LiveShow?
        if let onAirShow {
            show = LiveShow(name: onAirShow.title, host: nil, endsAt: nil)
        }
        // during a live show the "song" is nothing or the show's name, so keep only the show
        guard let metadata, show == nil || metadata.artist != nil else {
            return (.offAir, show)
        }
        var startedAt: Date?
        if let timestamp = metadata.playoutStartUnixTimestamp {
            startedAt = Date(timeIntervalSince1970: timestamp)
        }
        let track = NowPlaying(
            title: metadata.title,
            artist: metadata.artist ?? "Radio Monash",
            artworkURL: metadata.artwork?.best(),
            startedAt: startedAt,
            duration: metadata.duration
        )
        return (track, show)
    }

    private var metadata: LiveMetadata? {
        result.metadata
    }

    // the show, only once a presenter is actually on; playlist shows count as music
    private var onAirShow: LiveShowEvent? {
        guard let show = result.show else {
            return nil
        }
        if show.media?.type == "playlist" {
            return nil
        }
        // a live slot still playing library songs means the presenter hasn't connected yet
        let awaitingPresenter = show.media?.type == "live" && metadata?.trackId != nil
        if awaitingPresenter {
            return nil
        }
        return show
    }
}
