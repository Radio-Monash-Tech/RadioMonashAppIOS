import Foundation
import CryptoKit

/// Stores the photos of articles the user downloads, so a saved article reads
/// fully offline. Only text is kept for a plain bookmark; photos take the space.
/// Files live in Application Support, which iOS never clears on its own.
nonisolated enum ArticleDownloads {
    /// Every image an article shows, at the sizes the app asks for.
    @MainActor
    static func imageURLs(for article: Article) -> [URL] {
        var urls: [URL] = []
        if let cover = article.imageURL {
            urls += [cover.squarespaceSized(1000), cover.squarespaceSized(300)]
        }
        for case .image(let url, _) in ArticleHTMLParser.blocks(from: article.bodyHTML) {
            urls.append(url.squarespaceSized(1000))
        }
        return Array(Set(urls))
    }

    /// Downloads every image; `false` if any of them failed.
    static func download(_ urls: [URL]) async -> Bool {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    if FileManager.default.fileExists(atPath: file(for: url).path()) { return true }
                    guard let (data, response) = try? await URLSession.shared.data(from: url),
                          (response as? HTTPURLResponse)?.statusCode == 200
                    else { return false }
                    return (try? data.write(to: file(for: url), options: .atomic)) != nil
                }
            }
            return await group.allSatisfy { $0 }
        }
    }

    static func remove(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: file(for: url)) }
    }

    /// The downloaded copy of an image, if there is one.
    static func data(for url: URL) -> Data? {
        try? Data(contentsOf: file(for: url))
    }

    private static let folder = URL.applicationSupportDirectory.appending(path: "ArticleImages")

    /// Image links are long, so each file is named by a hash of its link.
    private static func file(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return folder.appending(path: hash.map { String(format: "%02x", $0) }.joined())
    }
}
