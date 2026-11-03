import SwiftUI
import UIKit

// MARK: - Image cache

// run it on main thread
@MainActor
final class ArtworkCache {
    // one cache for the whole app
    static let shared = ArtworkCache()

    // nsurl only accepts class objects as keys
    private let images = NSCache<NSURL, UIImage>()
    // downloads still in progress, so the same url is only downloaded once
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    // look up on the image
    func image(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    // load the image in
    func load(_ url: URL) async -> UIImage? {
        // already in memory
        if let cached = image(for: url) {
            return cached
        }
        // already downloading, wait for that one
        if let task = inFlight[url] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            // saved with an offline article
            if let data = ArticleDownloads.data(for: url) {
                return UIImage(data: data)
            }
            guard let (data, _) = try? await
                    URLSession.shared.data(from: url)
            else {
                return nil
            }
            return UIImage(data: data)
        }

        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        // only successful downloads are kept
        if let image {
            images.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    // empty the cache
    func removeAll() {
        images.removeAllObjects()
    }
}

// MARK: - Cached artwork view

// like AsyncImage, but uses the shared cache
struct CachedArtwork<Content: View, Placeholder: View>: View {
    let url: URL?
    // how the loaded image is shown
    @ViewBuilder let content: (Image) -> Content

    // use placeholder while image is still downloading
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

    // for placeholders that don't need isLoading
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(url: url, content: content, placeholder: { _ in
            placeholder()
        })
    }

    // cache first, then the last image this view loaded
    private var image: UIImage? {
        guard let url else {
            return nil
        }
        return ArtworkCache.shared.image(for: url) ?? lastLoaded
    }

    // there is a url and it hasn't failed
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
        // download again whenever the url changes
        .task(id: url) {
            guard let url else {
                return
            }
            if let loaded = await ArtworkCache.shared.load(url) {
                // fade the image in
                withAnimation(.easeIn(duration: 0.25)) {
                    lastLoaded = loaded
                }
            } else {
                failedURL = url
            }
        }
    }
}
