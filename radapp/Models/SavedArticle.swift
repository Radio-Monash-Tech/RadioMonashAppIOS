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
    /// Its photos are stored on the phone too, not just the text.
    var isDownloaded: Bool = false

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
            unsave(existing)
        } else {
            insert(SavedArticle(article: article))
            try? save()
        }
    }

    /// Removes the bookmark and any downloaded photos.
    func unsave(_ saved: SavedArticle) {
        if saved.isDownloaded {
            ArticleDownloads.remove(ArticleDownloads.imageURLs(for: saved.article))
        }
        delete(saved)
        try? save()
    }

    /// Downloads the article's photos, bookmarking it first if needed.
    /// Returns `false` if the download failed.
    func download(_ article: Article, existing: SavedArticle?) async -> Bool {
        let saved = existing ?? SavedArticle(article: article)
        if existing == nil { insert(saved) }
        let urls = ArticleDownloads.imageURLs(for: article)
        let succeeded = await ArticleDownloads.download(urls)
        if succeeded {
            saved.isDownloaded = true
        } else {
            ArticleDownloads.remove(urls)
        }
        try? save()
        return succeeded
    }

    /// Deletes the photos but keeps the bookmark.
    func removeDownload(_ saved: SavedArticle) {
        ArticleDownloads.remove(ArticleDownloads.imageURLs(for: saved.article))
        saved.isDownloaded = false
        try? save()
    }
}
