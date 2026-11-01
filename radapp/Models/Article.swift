import Foundation

// one journalism article from squarespace
struct Article: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var excerpt: String
    var author: String
    var publishedAt: Date
    var imageURL: URL?
    var webURL: URL?
    var bodyHTML: String
    var readMinutes: Int
    // the filter it's tagged under
    var topic: ArticleTopic? = nil

    // "Christopher Hall" becomes "CH"
    var authorInitials: String {
        let words = author.split(separator: " ")
        let firstLetters = words.compactMap(\.first)
        return firstLetters.prefix(2).map { letter in
            String(letter)
        }
        .joined()
    }
}
