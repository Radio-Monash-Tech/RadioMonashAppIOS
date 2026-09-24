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

    var billing: String {
        guard let host, !host.isEmpty else { return name }
        let firstName = host.split(separator: " ").first.map(String.init) ?? host
        return "\(name) with \(firstName)"
    }
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
