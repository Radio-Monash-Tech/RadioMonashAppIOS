import Foundation

// an error status from the itunes search
enum ITunesError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(403), .http(429):
            "Apple Music search is busy right now. Try again in a moment."
        case .http(let status):
            "Apple Music search returned an error (\(status))."
        }
    }
}

// finds radiocult's songs on itunes, for the apple music link; no key needed
struct ITunesClient {
    static let shared = ITunesClient()

    private let searchURL = URL(string: "https://itunes.apple.com/search")!

    // the matching song, nil if itunes doesn't have it; duration picks between releases
    func track(title: String, artist: String, duration: TimeInterval? = nil) async throws -> ITunesTrack? {
        let term = TrackName.searchTerm(title: title, artist: artist)
        guard !term.isEmpty else {
            return nil
        }

        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "country", value: "AU"),
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        // anything outside 200-299 is an error
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ITunesError.http(http.statusCode)
        }
        let results = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        return results.bestMatch(title: title, artist: artist, duration: duration)
    }
}
