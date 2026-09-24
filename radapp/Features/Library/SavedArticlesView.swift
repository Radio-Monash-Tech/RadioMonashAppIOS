import SwiftUI
import SwiftData

struct SavedArticlesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedArticle.savedAt, order: .reverse) private var savedArticles: [SavedArticle]

    var body: some View {
        Group {
            if savedArticles.isEmpty {
                ContentUnavailableView(
                    "No Saved Articles",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark in any article to keep it here for offline reading.")
                )
            } else {
                List {
                    ForEach(savedArticles) { saved in
                        let article = saved.article
                        NavigationLink(value: article) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title).font(.headline)
                                ArticleByline(article: article)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(savedArticles[index]) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .navigationTitle("Saved Articles")
    }
}
