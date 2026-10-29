import SwiftUI
import SwiftData

struct JournalismView: View {
    @EnvironmentObject private var journalism: JournalismStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentChoice) private var accent
    @Query private var savedArticles: [SavedArticle]
    @State private var path: [Article] = []
    @Environment(\.isLandscapePhone) private var isLandscape

    private var savedByID: [String: SavedArticle] {
        Dictionary(savedArticles.map { ($0.articleID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLandscape, let lead = journalism.articles.first {
                    // Latest story stays put on the left; the rest scroll on the right.
                    HStack(alignment: .top, spacing: 0) {
                        ScrollView {
                            leadCard(lead)
                                .padding(16)
                        }
                        .frame(maxWidth: .infinity)
                        articleList
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    articleList
                }
            }
            .navigationTitle("Journalism")
            .refreshable { await journalism.load() }
            .task { await journalism.loadIfNeeded() }
            .navigationDestination(for: Article.self) { ArticleView(article: $0) }
        }
    }

    private var articleList: some View {
        List {
            TopicFilter(selection: journalism.topic) { topic in
                Task { await journalism.select(topic) }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            if let savedAt = journalism.offlineCopyDate {
                OfflineNote(savedAt: savedAt)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            content
        }
        .listStyle(.plain)
    }

    /// The lead story in the landscape sidebar. It isn't a list row, so saving
    /// moves from a swipe to a long-press menu.
    private func leadCard(_ article: Article) -> some View {
        let savedCopy = savedByID[article.id]
        return Button {
            path.append(article)
        } label: {
            FeatureCard(article: article, isSaved: savedCopy != nil) {
                modelContext.toggleSaved(article, existing: savedCopy)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                modelContext.toggleSaved(article, existing: savedCopy)
            } label: {
                Label(savedCopy == nil ? "Save" : "Unsave",
                      systemImage: savedCopy == nil ? "bookmark.fill" : "bookmark.slash.fill")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if journalism.articles.isEmpty {
            switch journalism.phase {
            case .idle, .loading:
                Group {
                    FeatureCard(article: .placeholder(0))
                        .articleListRow()
                    ForEach(1..<5, id: \.self) {
                        ArticleRow(article: .placeholder($0))
                            .articleListRow()
                    }
                }
                .redacted(reason: .placeholder)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Articles Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await journalism.load() } }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 40)
                .articleListRow()
            case .loaded:
                ContentUnavailableView(
                    "No Articles Yet",
                    systemImage: "newspaper",
                    description: Text("New pieces from the Radio Monash newsroom will appear here.")
                )
                .padding(.top, 40)
                .articleListRow()
            }
        } else {
            let saved = savedByID
            // In landscape the lead story is in the sidebar, so the list starts at the second.
            let listed = Array(journalism.articles.enumerated()).dropFirst(isLandscape ? 1 : 0)
            ForEach(listed, id: \.element.id) { index, article in
                let savedCopy = saved[article.id]
                Button {
                    path.append(article)
                } label: {
                    let toggleSave = { modelContext.toggleSaved(article, existing: savedCopy) }
                    if index == 0 {
                        FeatureCard(article: article, isSaved: savedCopy != nil, onToggleSave: toggleSave)
                    } else {
                        ArticleRow(article: article, isSaved: savedCopy != nil, onToggleSave: toggleSave)
                    }
                }
                .buttonStyle(.plain)
                .articleListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        modelContext.toggleSaved(article, existing: savedCopy)
                    } label: {
                        Label(savedCopy == nil ? "Save" : "Unsave",
                              systemImage: savedCopy == nil ? "bookmark.fill" : "bookmark.slash.fill")
                    }
                    .tint(savedCopy == nil ? accent.color : .gray)
                }
                .onAppear {
                    if article.id == journalism.articles.last?.id {
                        Task { await journalism.loadMore() }
                    }
                }
            }

            if journalism.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .articleListRow()
            } else if journalism.loadMoreFailed {
                Button("Load More Articles") { Task { await journalism.loadMore() } }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .articleListRow()
            }
        }
    }
}

private extension View {
    func articleListRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Components

private struct FeatureCard: View {
    let article: Article
    var isSaved = false
    var onToggleSave: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkImage(url: article.imageURL?.squarespaceSized(1000))
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            ArticleSource(article: article, isLatest: true)
            Text(article.title)
                .font(.title3.bold())
            if !article.excerpt.isEmpty {
                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            ArticleFooter(article: article, isSaved: isSaved, onToggleSave: onToggleSave)
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// An Apple News–style card: topic and title on the left, a square photo on the right.
private struct ArticleRow: View {
    let article: Article
    var isSaved = false
    var onToggleSave: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var imageSize: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // At the largest sizes the title needs the full width, so the photo goes on top.
            if typeSize.isAccessibilitySize {
                ArtworkImage(url: article.imageURL?.squarespaceSized(1000))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                headline
            } else {
                HStack(alignment: .top, spacing: 14) {
                    headline
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ArtworkImage(url: article.imageURL?.squarespaceSized(300))
                        .frame(width: min(imageSize, 140), height: min(imageSize, 140))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            ArticleFooter(article: article, isSaved: isSaved, onToggleSave: onToggleSave)
        }
        .padding(14)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            ArticleSource(article: article)
            Text(article.title)
                .font(.title3.weight(.semibold))
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The label above a title, where Apple News shows the publisher.
private struct ArticleSource: View {
    let article: Article
    var isLatest = false

    var body: some View {
        let topic = article.topic?.label ?? "Radio Monash"
        Text(isLatest ? "Latest · \(topic)" : topic)
            .font(.footnote.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(.tint)
            .lineLimit(1)
    }
}

/// Byline on the left, the ••• menu on the right.
private struct ArticleFooter: View {
    let article: Article
    let isSaved: Bool
    let onToggleSave: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            ArticleByline(article: article, isSaved: isSaved)
            Spacer(minLength: 8)
            Menu {
                Button(action: onToggleSave) {
                    Label(isSaved ? "Remove from Saved" : "Save Article",
                          systemImage: isSaved ? "bookmark.slash" : "bookmark")
                }
                Button {
                    SystemPresenter.share(article.webURL ?? SquarespaceClient.siteURL)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More")
        }
    }
}

extension Article {
    static func placeholder(_ index: Int) -> Article {
        Article(
            id: "placeholder-\(index)",
            title: "Loading an article from the Radio Monash newsroom",
            excerpt: "A short summary of the article appears here.",
            author: "Radio Monash",
            publishedAt: .now,
            imageURL: nil,
            webURL: nil,
            bodyHTML: "",
            readMinutes: 1
        )
    }
}

#Preview {
    JournalismView()
        .environmentObject(JournalismStore())
        .modelContainer(for: SavedArticle.self, inMemory: true)
}

/// The row of filter pills at the top of Journalism.
private struct TopicFilter: View {
    let selection: ArticleTopic?
    let onSelect: (ArticleTopic?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("All", topic: nil)
                ForEach(ArticleTopic.allCases) { pill($0.label, topic: $0) }
            }
            .padding(.horizontal, 16)
        }
    }

    private func pill(_ title: String, topic: ArticleTopic?) -> some View {
        TopicPill(title: title, isSelected: selection == topic) { onSelect(topic) }
    }
}

private struct TopicPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accentChoice) private var accent

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? accent.onColor : Color.primary)
                .background(
                    isSelected ? AnyShapeStyle(accent.color) : AnyShapeStyle(.fill.tertiary),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
