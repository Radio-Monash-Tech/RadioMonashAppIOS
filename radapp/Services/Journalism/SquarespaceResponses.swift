import Foundation

// MARK: - Wire format: GET /<collection>?format=json

struct SquarespaceCollectionResponse: Decodable {
    let items: [SquarespaceItem]?
    let pagination: SquarespacePagination?
}

struct SquarespacePagination: Decodable {
    let nextPage: Bool?
    let nextPageOffset: Int64?
}

struct SquarespaceItem: Decodable {
    let id: String
    let title: String?
    let fullUrl: String?
    let publishOn: Double?
    let addedOn: Double?
    let excerpt: String?
    let body: String?
    let assetUrl: String?
    let author: SquarespaceAuthor?
}

struct SquarespaceAuthor: Decodable {
    let displayName: String?
}

extension SquarespaceItem {
    func toArticle() -> Article? {
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }

        let bodyHTML = body ?? ""
        let wordCount = ArticleHTMLParser.plainText(from: bodyHTML)
            .split(whereSeparator: \.isWhitespace)
            .count
        let authorName = author?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let publishedMilliseconds = publishOn ?? addedOn ?? 0

        return Article(
            id: id,
            title: title,
            excerpt: ArticleHTMLParser.plainText(from: excerpt ?? ""),
            author: authorName.flatMap { $0.isEmpty ? nil : $0 } ?? "Radio Monash",
            publishedAt: Date(timeIntervalSince1970: publishedMilliseconds / 1000),
            imageURL: assetUrl.flatMap(URL.init(string:)),
            webURL: fullUrl.flatMap { URL(string: $0, relativeTo: SquarespaceClient.siteURL)?.absoluteURL },
            bodyHTML: bodyHTML,
            readMinutes: max(1, Int((Double(wordCount) / 200).rounded(.up)))
        )
    }
}
