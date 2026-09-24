import SwiftUI
import UIKit

@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private let images = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    func image(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let cached = image(for: url) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return UIImage(data: data)
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { images.setObject(image, forKey: url as NSURL) }
        return image
    }

    func removeAll() {
        images.removeAllObjects()
    }
}

struct CachedArtwork<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var lastLoaded: UIImage?

    private var image: UIImage? {
        guard let url else { return nil }
        return ArtworkCache.shared.image(for: url) ?? lastLoaded
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let loaded = await ArtworkCache.shared.load(url) {
                lastLoaded = loaded
            }
        }
    }
}
