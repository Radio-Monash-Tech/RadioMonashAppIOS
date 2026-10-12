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
    /// Receives `true` while the image is still downloading, `false` when there is no image to show.
    @ViewBuilder let placeholder: (_ isLoading: Bool) -> Placeholder

    @State private var lastLoaded: UIImage?
    @State private var failedURL: URL?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping (_ isLoading: Bool) -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(url: url, content: content, placeholder: { _ in placeholder() })
    }

    private var image: UIImage? {
        guard let url else { return nil }
        return ArtworkCache.shared.image(for: url) ?? lastLoaded
    }

    private var isLoading: Bool {
        url != nil && failedURL != url
    }

    var body: some View {
        ZStack {
            if let image {
                content(Image(uiImage: image))
                    .transition(.opacity)
            } else {
                placeholder(isLoading)
                    .transition(.opacity)
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let loaded = await ArtworkCache.shared.load(url) {
                withAnimation(.easeIn(duration: 0.25)) {
                    lastLoaded = loaded
                }
            } else {
                failedURL = url
            }
        }
    }
}
