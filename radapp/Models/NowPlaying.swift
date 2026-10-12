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
    var host: String?
    var endsAt: Date?
}

struct PlayedTrack: Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var playedAt: Date
    var artworkURL: URL?
}

extension PlayedTrack {
    /// The same song at (nearly) the same start time. RadioCult's history and
    /// live feed round start times differently, so allow a little slack.
    func isSamePlay(as other: PlayedTrack) -> Bool {
        title == other.title && artist == other.artist
            && abs(playedAt.timeIntervalSince(other.playedAt)) < 30
    }
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
