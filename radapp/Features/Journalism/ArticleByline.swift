import SwiftUI

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
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Saved")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
