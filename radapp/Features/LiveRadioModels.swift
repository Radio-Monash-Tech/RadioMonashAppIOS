import Foundation

struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var artworkURL: URL?
    var startedAt: Date?
    var duration: TimeInterval?

    static let offAir = NowPlaying(
        title: "Radio Monash",
        artist: "Default playlist",
        artworkURL: nil,
        startedAt: nil,
        duration: nil
    )
}

struct LiveShow: Equatable {
    var name: String
    var host: String
    var endsAt: Date?

    var billing: String { "\(name) with \(host.split(separator: " ").first.map(String.init) ?? host)" }
}

struct PlayedTrack: Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var playedAt: Date
    var artworkURL: URL?
}

// MARK: - Stream / connectivity state

enum StreamState: Equatable {
    case idle
    case connecting
    case playing
    case paused
    case failed(String)
}

enum Connectivity: Equatable {
    case good, weak, offline

    var banner: String? {
        switch self {
        case .good: return nil
        case .weak: return "Weak connection — stream may buffer"
        case .offline: return "Offline — showing cached schedule and saved articles"
        }
    }
}

// MARK: - Navigation

enum LiveRoute: Hashable { case liked, statistics, history }

// MARK: - Wire format

/// Shape of the RadioCult now-playing response, flattened to what the UI needs.
struct NowPlayingPayload: Decodable {
    let track: NowPlaying
    let show: LiveShow?
    let history: [PlayedTrack]

    // Provide a custom init mapping the live API's keys onto these types.
    init(from decoder: Decoder) throws {
        track = .offAir
        show = nil
        history = []
    }
}
