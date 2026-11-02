import SwiftUI
import SwiftData

// MARK: - Journalism view

// the journalism tab: topic filter and the article list
struct JournalismView: View {
    // MARK: - State

    @EnvironmentObject private var journalism: JournalismStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accentChoice) private var accent
    @Query private var savedArticles: [SavedArticle]
    // the articles opened, for the navigation stack
    @State private var path: [Article] = []
    @Environment(\.isLandscapePhone) private var isLandscape

    // saved articles looked up by article id
    private var savedByID: [String: SavedArticle] {
        let pairs = savedArticles.map { saved in
            (saved.articleID, saved)
        }
        // keep the first if one article was saved twice
        return Dictionary(pairs, uniquingKeysWith: { first, _ in
            first
        })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLandscape, let lead = journalism.articles.first {
                    // latest story on the left, the rest scroll on the right
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
            // pull to refresh
            .refreshable {
                await journalism.load()
            }
            .task {
                await journalism.loadIfNeeded()
            }
            // opening an article
            .navigationDestination(for: Article.self) { article in
                ArticleView(article: article)
            }
        }
    }

    // MARK: - Article list

    private var articleList: some View {
        List {
            TopicFilter(selection: journalism.topic) { topic in
                Task {
                    await journalism.select(topic)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            // showing the saved copy because loading failed
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

    // the lead story in landscape; not a list row, so saving is a long press instead of a swipe
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
                // grey placeholder cards while loading
                Group {
                    FeatureCard(article: .placeholder(0))
                        .articleListRow()
                    ForEach(1..<5, id: \.self) { index in
                        ArticleRow(article: .placeholder(index))
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
                    Button("Try Again") {
                        Task {
                            await journalism.load()
                        }
                    }
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
            // in landscape the lead story is in the sidebar, so the list starts at the second
            let listed = Array(journalism.articles.enumerated()).dropFirst(isLandscape ? 1 : 0)
            ForEach(listed, id: \.element.id) { index, article in
                let savedCopy = saved[article.id]
                Button {
                    path.append(article)
                } label: {
                    let toggleSave = {
                        modelContext.toggleSaved(article, existing: savedCopy)
                    }
                    // the first article gets the big card
                    if index == 0 {
                        FeatureCard(article: article, isSaved: savedCopy != nil, onToggleSave: toggleSave)
                    } else {
                        ArticleRow(article: article, isSaved: savedCopy != nil, onToggleSave: toggleSave)
                    }
                }
                .buttonStyle(.plain)
                .articleListRow()
                // swipe left to save or unsave
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        modelContext.toggleSaved(article, existing: savedCopy)
                    } label: {
                        Label(savedCopy == nil ? "Save" : "Unsave",
                              systemImage: savedCopy == nil ? "bookmark.fill" : "bookmark.slash.fill")
                    }
                    .tint(savedCopy == nil ? accent.color : .gray)
                }
                // load the next page when the last article appears
                .onAppear {
                    if article.id == journalism.articles.last?.id {
                        Task {
                            await journalism.loadMore()
                        }
                    }
                }
            }

            if journalism.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .articleListRow()
            } else if journalism.loadMoreFailed {
                Button("Load More Articles") {
                    Task {
                        await journalism.loadMore()
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .articleListRow()
            }
        }
    }
}

// MARK: - Row style

private extension View {
    // the spacing and clear background every row uses
    func articleListRow() -> some View {
        listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Feature card

// the big card for the latest article
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
        // the whole card is tappable
        .contentShape(Rectangle())
    }
}

// MARK: - Article row

// apple news style row: title on the left, square photo on the right
private struct ArticleRow: View {
    let article: Article
    var isSaved = false
    var onToggleSave: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    // grows with the user's text size
    @ScaledMetric(relativeTo: .headline) private var imageSize: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // at the largest text sizes the photo goes on top so the title gets the full width
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

    // topic and title
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

// MARK: - Topic label

// the coloured topic label above a title
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

// MARK: - Article footer

// byline on the left, ••• menu on the right
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
                // SystemPresenter because ShareLink breaks inside a Menu
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

// MARK: - Placeholders

extension Article {
    // a fake article for loading placeholders and previews
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

// MARK: - Preview

#Preview {
    JournalismView()
        .environmentObject(JournalismStore())
        .modelContainer(for: SavedArticle.self, inMemory: true)
}

// MARK: - Topic filter

// the row of topic pills at the top
private struct TopicFilter: View {
    let selection: ArticleTopic?
    let onSelect: (ArticleTopic?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // nil means all topics
                pill("All", topic: nil)
                ForEach(ArticleTopic.allCases) { topic in
                    pill(topic.label, topic: topic)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func pill(_ title: String, topic: ArticleTopic?) -> some View {
        TopicPill(title: title, isSelected: selection == topic) {
            onSelect(topic)
        }
    }
}

// MARK: - Topic pill

// one topic button, filled with the accent colour when selected
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
        // voiceover says "selected"
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
