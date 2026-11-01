import Foundation
import CryptoKit

// saves downloaded articles' photos so they read fully offline; ios never clears this folder
nonisolated enum ArticleDownloads {
    // every image an article shows, at the sizes the app asks for
    @MainActor
    static func imageURLs(for article: Article) -> [URL] {
        var urls: [URL] = []
        if let cover = article.imageURL {
            urls += [cover.squarespaceSized(1000), cover.squarespaceSized(300)]
        }
        for case .image(let url, _) in ArticleHTMLParser.blocks(from: article.bodyHTML) {
            urls.append(url.squarespaceSized(1000))
        }
        // without repeats
        return Array(Set(urls))
    }

    // downloads every image at the same time; false if any failed
    static func download(_ urls: [URL]) async -> Bool {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask {
                    // already saved
                    if FileManager.default.fileExists(atPath: file(for: url).path()) {
                        return true
                    }
                    guard let (data, response) = try? await URLSession.shared.data(from: url),
                          (response as? HTTPURLResponse)?.statusCode == 200
                    else {
                        return false
                    }
                    return (try? data.write(to: file(for: url), options: .atomic)) != nil
                }
            }
            return await group.allSatisfy { succeeded in
                succeeded
            }
        }
    }

    static func remove(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: file(for: url))
        }
    }

    // the saved copy of an image, if there is one
    static func data(for url: URL) -> Data? {
        try? Data(contentsOf: file(for: url))
    }

    private static let folder = URL.applicationSupportDirectory.appending(path: "ArticleImages")

    // image links are long, so each file is named by a hash of its link
    private static func file(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = hash.map { byte in
            String(format: "%02x", byte)
        }
        return folder.appending(path: hex.joined())
    }
}
