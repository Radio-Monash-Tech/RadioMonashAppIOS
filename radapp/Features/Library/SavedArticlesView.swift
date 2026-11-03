import SwiftUI
import SwiftData

// every bookmarked article, newest first
struct SavedArticlesView: View {
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.modelContext) private var modelContext
    // @Query macro, loads SwiftData records and keeps them up to date
    @Query(sort: \SavedArticle.savedAt, order: .reverse) private var savedArticles: [SavedArticle]

    var body: some View {
        Group {
            if savedArticles.isEmpty {
                ContentUnavailableView(
                    "No Saved Articles",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark in any article to keep its text here. Tap download to keep its photos too.")
                )
            } else {
                List {
                    ForEach(savedArticles) { saved in
                        // the saved copy turned back into an Article
                        let article = saved.article
                        // opens through LibraryView's Article destination
                        NavigationLink(value: article) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title).font(.headline)
                                ArticleByline(article: article)
                                if saved.isDownloaded {
                                    Label("Downloaded", systemImage: "arrow.down.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    // swipe to delete
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.unsave(savedArticles[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved Articles")
    }
}
