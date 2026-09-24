import Foundation

struct Article: Identifiable, Hashable {
    let id: String
    var title: String
    var excerpt: String
    var author: String
    var publishedAt: Date
    var imageURL: URL?
    var webURL: URL?
    var bodyHTML: String
    var readMinutes: Int

    var authorInitials: String {
        author.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }
}
