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

    private let client = SquarespaceClient.shared
    private var nextOffset: Int64?
    private var loadedAt: Date?
    private let staleAfter: TimeInterval = 15 * 60

    var hasMore: Bool { nextOffset != nil }

    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < staleAfter { return }
        guard phase != .loading else { return }
        await load()
    }

    func load() async {
        phase = .loading
        do {
            let page = try await client.articles()
            articles = page.articles
            nextOffset = page.nextOffset
            loadMoreFailed = false
            loadedAt = .now
            phase = .loaded
        } catch {
            if Self.isCancellation(error) {
                phase = articles.isEmpty ? .idle : .loaded
            } else {
                phase = .failed(Self.message(for: error))
            }
        }
    }

    func loadMore() async {
        guard let nextOffset, !isLoadingMore, phase == .loaded else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.articles(after: nextOffset)
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
