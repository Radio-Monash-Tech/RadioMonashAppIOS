import Foundation

enum SquarespaceError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(let status): "The Radio Monash website returned an error (\(status))."
        }
    }
}

struct ArticlePage {
    let articles: [Article]
    let nextOffset: Int64?
}

struct SquarespaceClient {
    static let shared = SquarespaceClient()
    static let siteURL = URL(string: "https://www.radiomonash.online")!

    private let journalismPath = "journalism-all"

    func articles(after offset: Int64? = nil) async throws -> ArticlePage {
        var components = URLComponents(
            url: Self.siteURL.appendingPathComponent(journalismPath),
            resolvingAgainstBaseURL: false
        )!
        var query = [URLQueryItem(name: "format", value: "json")]
        if let offset { query.append(URLQueryItem(name: "offset", value: String(offset))) }
        components.queryItems = query

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SquarespaceError.http(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(SquarespaceCollectionResponse.self, from: data)
        return ArticlePage(
            articles: (decoded.items ?? []).compactMap { $0.toArticle() },
            nextOffset: decoded.pagination?.nextPage == true ? decoded.pagination?.nextPageOffset : nil
        )
    }
}
