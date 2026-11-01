import Foundation

// radiocult's artwork: a size label ("512x512", "default" ...) for each url
struct ArtworkVariants: Decodable {
    let urls: [String: URL]

    // bad urls are skipped instead of failing the whole response
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: String].self)
        urls = raw.compactMapValues(URL.init)
    }

    // the first size on the list that exists, otherwise any
    func best(preferring order: [String] = ["512x512", "default", "original"]) -> URL? {
        for key in order {
            if let url = urls[key] {
                return url
            }
        }
        return urls.values.first
    }
}
