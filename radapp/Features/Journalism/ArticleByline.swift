import SwiftUI

// "Author · 3 Nov 2026" with a bookmark when saved
struct ArticleByline: View {
    let article: Article
    var isSaved = false

    var body: some View {
        HStack(spacing: 4) {
            Text(article.author).fontWeight(.medium)
            Text("·")
            Text(article.publishedAt, format: .dateTime.day().month(.abbreviated).year())
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Saved")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
