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
            FeatureCard(article: article, isSaved: savedCopy != nil)
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
                    if index == 0 {
                        FeatureCard(article: article, isSaved: savedCopy != nil)
                    } else {
                        ArticleRow(article: article, isSaved: savedCopy != nil)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkImage(url: article.imageURL?.squarespaceSized(1000))
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("LATEST")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tint)
            Text(article.title)
                .font(.title3.bold())
            if !article.excerpt.isEmpty {
                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            ArticleByline(article: article, isSaved: isSaved)
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct ArticleRow: View {
    let article: Article
    var isSaved = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(3)
                ArticleByline(article: article, isSaved: isSaved)
            }
            Spacer(minLength: 0)
            ArtworkImage(url: article.imageURL?.squarespaceSized(300))
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .contentShape(Rectangle())
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
