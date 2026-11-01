import Foundation

// the song radiocult says is playing
struct NowPlaying: Equatable {
    var title: String
    var artist: String
    var artworkURL: URL?
    var startedAt: Date?
    var duration: TimeInterval?

    // shown when no song is named
    static let offAir = NowPlaying(
        title: "Radio Monash",
        artist: "Default playlist",
        artworkURL: nil,
        startedAt: nil,
        duration: nil
    )
}

// a show broadcasting right now
struct LiveShow: Equatable {
    var name: String
    var host: String?
    var endsAt: Date?
}

// one song in the play history
struct PlayedTrack: Identifiable, Equatable {
    let id: String
    var title: String
    var artist: String
    var playedAt: Date
    var artworkURL: URL?
}

extension PlayedTrack {
    // same song within 30 seconds; radiocult's feeds round times differently
    func isSamePlay(as other: PlayedTrack) -> Bool {
        title == other.title && artist == other.artist
            && abs(playedAt.timeIntervalSince(other.playedAt)) < 30
    }
}

// where the audio stream is up to
enum StreamState: Equatable {
    case idle
    case connecting
    case playing
    case paused
    case failed(String)
}

// how good the connection is
enum Connectivity: Equatable {
    case good, weak, offline

    // the warning to show, nil when fine
    var banner: String? {
        switch self {
        case .good:
            return nil
        case .weak:
            return "Weak connection — stream may buffer"
        case .offline:
            return "Offline — showing cached schedule and saved articles"
        }
    }
}
