import Foundation
import Combine

@MainActor
final class JournalismStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed(String)
    }

    @Published private(set) var articles: [Article] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreFailed = false
    /// The filter picked at the top of Journalism; `nil` is All.
    @Published private(set) var topic: ArticleTopic?
    /// When the shown articles were downloaded, set only while the latest
    /// download failed and the saved copy is on screen instead.
    @Published private(set) var offlineCopyDate: Date?

    private let client = SquarespaceClient.shared
    private var nextOffset: Int64?
    private var loadedAt: Date?
    private var cachedAt: Date?
    private let staleAfter: TimeInterval = 15 * 60

    var hasMore: Bool { nextOffset != nil }

    init() {
        showSavedCopy()
    }

    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < staleAfter { return }
        guard phase != .loading else { return }
        await load()
    }

    /// Switches filter and loads its first page.
    func select(_ topic: ArticleTopic?) async {
        guard topic != self.topic else { return }
        self.topic = topic
        nextOffset = nil
        offlineCopyDate = nil
        showSavedCopy()
        await load()
    }

    /// Puts the saved first page for the current filter on screen, if there is one.
    private func showSavedCopy() {
        let cached = OfflineCache.load([Article].self, named: cacheName(for: topic))
        articles = cached?.value ?? []
        cachedAt = cached?.savedAt
    }

    /// One saved first page per filter: "articles-all", "articles-popCulture"…
    private func cacheName(for topic: ArticleTopic?) -> String {
        "articles-" + (topic.map { "\($0)" } ?? "all")
    }

    func load() async {
        let topic = topic
        phase = .loading
        do {
            let page = try await client.articles(tag: topic?.siteTag)
            // Another filter was picked while this one loaded.
            guard topic == self.topic else { return }
            articles = page.articles
            nextOffset = page.nextOffset
            loadMoreFailed = false
            loadedAt = .now
            cachedAt = .now
            offlineCopyDate = nil
            phase = .loaded
            OfflineCache.save(page.articles, as: cacheName(for: topic))
        } catch {
            guard topic == self.topic else { return }
            if Self.isCancellation(error) {
                phase = articles.isEmpty ? .idle : .loaded
            } else if !articles.isEmpty {
                // Keep showing the saved copy rather than an error.
                offlineCopyDate = cachedAt
                phase = .loaded
            } else {
                phase = .failed(Self.message(for: error))
            }
        }
    }

    func loadMore() async {
        guard let nextOffset, !isLoadingMore, phase == .loaded else { return }
        let topic = topic
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.articles(tag: topic?.siteTag, after: nextOffset)
            guard topic == self.topic else { return }
            let known = Set(articles.map(\.id))
            articles += page.articles.filter { !known.contains($0.id) }
            self.nextOffset = page.nextOffset
            loadMoreFailed = false
        } catch {
            loadMoreFailed = !Self.isCancellation(error)
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private static func message(for error: Error) -> String {
        if (error as? URLError)?.code == .notConnectedToInternet {
            return "You're offline. Saved articles are still available in your Library."
        }
        return (error as? LocalizedError)?.errorDescription ?? "Couldn't load articles from Radio Monash."
    }
}
