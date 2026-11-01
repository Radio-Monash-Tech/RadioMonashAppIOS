import Foundation

// the json from /journalism-all?format=json
struct SquarespaceCollectionResponse: Decodable {
    let items: [SquarespaceItem]?
    let pagination: SquarespacePagination?
}

struct SquarespacePagination: Decodable {
    let nextPage: Bool?
    let nextPageOffset: Int64?
}

// one article as squarespace sends it
struct SquarespaceItem: Decodable {
    let id: String
    let title: String?
    let fullUrl: String?
    // milliseconds since 1970
    let publishOn: Double?
    let addedOn: Double?
    let excerpt: String?
    let body: String?
    let assetUrl: String?
    let author: SquarespaceAuthor?
    let tags: [String]?
}

struct SquarespaceAuthor: Decodable {
    let displayName: String?
}

extension SquarespaceItem {
    // the app's own article, nil if it has no title
    func toArticle() -> Article? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }

        let bodyHTML = body ?? ""
        let wordCount = ArticleHTMLParser.plainText(from: bodyHTML)
            .split(whereSeparator: \.isWhitespace)
            .count
        // 200 words a minute, at least 1 minute
        let readMinutes = max(1, Int((Double(wordCount) / 200).rounded(.up)))

        // the author's name, or the station's if there isn't one
        var byline = "Radio Monash"
        if let name = author?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            byline = name
        }

        let publishedMilliseconds = publishOn ?? addedOn ?? 0

        // the link to the article on the website
        var webURL: URL?
        if let fullUrl {
            webURL = URL(string: fullUrl, relativeTo: SquarespaceClient.siteURL)?.absoluteURL
        }

        return Article(
            id: id,
            title: title,
            excerpt: ArticleHTMLParser.plainText(from: excerpt ?? ""),
            author: byline,
            publishedAt: Date(timeIntervalSince1970: publishedMilliseconds / 1000),
            imageURL: assetUrl.flatMap(URL.init(string:)),
            webURL: webURL,
            bodyHTML: bodyHTML,
            readMinutes: readMinutes,
            topic: ArticleTopic(tags: tags ?? [])
        )
    }
}
