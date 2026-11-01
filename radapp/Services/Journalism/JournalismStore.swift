import Foundation
import Combine

// the articles for the journalism tab, with paging and an offline copy
@MainActor
final class JournalismStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed(String)
    }

    @Published private(set) var articles: [Article] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreFailed = false
    // the topic picked at the top; nil is all
    @Published private(set) var topic: ArticleTopic?
    // set only while showing the saved copy because loading failed
    @Published private(set) var offlineCopyDate: Date?

    private let client = SquarespaceClient.shared
    // where the next page starts; nil when there are no more
    private var nextOffset: Int64?
    private var loadedAt: Date?
    private var cachedAt: Date?
    // reload after 15 minutes
    private let staleAfter: TimeInterval = 15 * 60

    var hasMore: Bool {
        nextOffset != nil
    }

    init() {
        showSavedCopy()
    }

    // loads unless it was loaded in the last 15 minutes
    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < staleAfter {
            return
        }
        guard phase != .loading else {
            return
        }
        await load()
    }

    // switches topic and loads its first page
    func select(_ topic: ArticleTopic?) async {
        guard topic != self.topic else {
            return
        }
        self.topic = topic
        nextOffset = nil
        offlineCopyDate = nil
        showSavedCopy()
        await load()
    }

    // shows the saved first page for this topic, if there is one
    private func showSavedCopy() {
        let cached = OfflineCache.load([Article].self, named: cacheName(for: topic))
        articles = cached?.value ?? []
        cachedAt = cached?.savedAt
    }

    // one saved first page per topic: "articles-all", "articles-popCulture" ...
    private func cacheName(for topic: ArticleTopic?) -> String {
        guard let topic else {
            return "articles-all"
        }
        return "articles-\(topic)"
    }

    // the first page for the current topic
    func load() async {
        let topic = topic
        phase = .loading
        do {
            let page = try await client.articles(tag: topic?.siteTag)
            // another topic was picked while this one loaded
            guard topic == self.topic else {
                return
            }
            articles = page.articles
            nextOffset = page.nextOffset
            loadMoreFailed = false
            loadedAt = .now
            cachedAt = .now
            offlineCopyDate = nil
            phase = .loaded
            OfflineCache.save(page.articles, as: cacheName(for: topic))
        } catch {
            guard topic == self.topic else {
                return
            }
            if Self.isCancellation(error) {
                if articles.isEmpty {
                    phase = .idle
                } else {
                    phase = .loaded
                }
            } else if !articles.isEmpty {
                // keep showing the saved copy rather than an error
                offlineCopyDate = cachedAt
                phase = .loaded
            } else {
                phase = .failed(Self.message(for: error))
            }
        }
    }

    // the next page, added to the end
    func loadMore() async {
        guard let nextOffset, !isLoadingMore, phase == .loaded else {
            return
        }
        let topic = topic
        isLoadingMore = true
        defer {
            isLoadingMore = false
        }
        do {
            let page = try await client.articles(tag: topic?.siteTag, after: nextOffset)
            guard topic == self.topic else {
                return
            }
            // skip any already in the list
            let known = Set(articles.map(\.id))
            articles += page.articles.filter { article in
                !known.contains(article.id)
            }
            self.nextOffset = page.nextOffset
            loadMoreFailed = false
        } catch {
            loadMoreFailed = !Self.isCancellation(error)
        }
    }

    // the load was cancelled, not failed
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
