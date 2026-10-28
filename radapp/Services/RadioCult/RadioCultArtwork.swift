import Foundation

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
