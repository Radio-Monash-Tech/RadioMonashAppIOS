import Foundation

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
    /// The filter it's tagged under, shown as its label in the list.
    var topic: ArticleTopic? = nil

    var authorInitials: String {
        author.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }
}
