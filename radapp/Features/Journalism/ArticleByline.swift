import SwiftUI

struct ArticleByline: View {
    let article: Article

    var body: some View {
        HStack(spacing: 4) {
            Text(article.author).fontWeight(.medium)
            Text("·")
            Text(article.publishedAt, format: .dateTime.day().month(.abbreviated).year())
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
