import Foundation
import SwiftData

@Model
final class SavedArticle {
    @Attribute(.unique) var articleID: String
    var title: String
    var excerpt: String
    var author: String
    var publishedAt: Date
    var imageURL: URL?
    var webURL: URL?
    var bodyHTML: String
    var readMinutes: Int
    var savedAt: Date

    init(article: Article, savedAt: Date = .now) {
        articleID = article.id
        title = article.title
        excerpt = article.excerpt
        author = article.author
        publishedAt = article.publishedAt
        imageURL = article.imageURL
        webURL = article.webURL
        bodyHTML = article.bodyHTML
        readMinutes = article.readMinutes
        self.savedAt = savedAt
    }

    var article: Article {
        Article(
            id: articleID,
            title: title,
            excerpt: excerpt,
            author: author,
            publishedAt: publishedAt,
            imageURL: imageURL,
            webURL: webURL,
            bodyHTML: bodyHTML,
            readMinutes: readMinutes
        )
    }
}

extension ModelContext {
    func toggleSaved(_ article: Article, existing: SavedArticle?) {
        if let existing {
            delete(existing)
        } else {
            insert(SavedArticle(article: article))
        }
        try? save()
    }
}
