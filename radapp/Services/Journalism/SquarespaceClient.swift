import Foundation

// an error status from the website
enum SquarespaceError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(let status):
            "The Radio Monash website returned an error (\(status))."
        }
    }
}

// one page of articles and where the next one starts
struct ArticlePage {
    let articles: [Article]
    let nextOffset: Int64?
}

// loads articles from the radio monash squarespace site
struct SquarespaceClient {
    static let shared = SquarespaceClient()
    static let siteURL = URL(string: "https://www.radiomonash.online")!

    private let journalismPath = "journalism-all"

    // one page, newest first; squarespace does the tag filtering so paging still works
    func articles(tag: String? = nil, after offset: Int64? = nil) async throws -> ArticlePage {
        var components = URLComponents(
            url: Self.siteURL.appendingPathComponent(journalismPath),
            resolvingAgainstBaseURL: false
        )!
        var query = [URLQueryItem(name: "format", value: "json")]
        if let tag {
            query.append(URLQueryItem(name: "tag", value: tag))
        }
        if let offset {
            query.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components.queryItems = query

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        // anything outside 200-299 is an error
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SquarespaceError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(SquarespaceCollectionResponse.self, from: data)
        let articles = (decoded.items ?? []).compactMap { item in
            item.toArticle()
        }
        // only an offset when squarespace says there's another page
        var nextOffset: Int64?
        if decoded.pagination?.nextPage == true {
            nextOffset = decoded.pagination?.nextPageOffset
        }
        return ArticlePage(articles: articles, nextOffset: nextOffset)
    }
}
