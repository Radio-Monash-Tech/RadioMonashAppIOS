import SwiftUI

struct SavedArticlesView: View {
    @AppStorage(StoredIDs.savedArticlesKey) private var saved = StoredIDs()

    private var articles: [Article] {
        SampleContent.articles.filter { saved.contains($0.id) }
    }

    var body: some View {
        Group {
            if articles.isEmpty {
                ContentUnavailableView(
                    "No Saved Articles",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark in any article to keep it here for offline reading.")
                )
            } else {
                List {
                    ForEach(articles) { article in
                        NavigationLink(value: article) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title).font(.headline)
                                ArticleByline(article: article)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { saved.toggle(articles[index].id) }
                    }
                }
            }
        }
        .navigationTitle("Saved Articles")
    }
}
