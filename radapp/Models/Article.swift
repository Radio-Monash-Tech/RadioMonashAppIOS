import Foundation

enum ArticleCategory: String, CaseIterable, Identifiable {
    case music = "Music", campus = "Campus", reviews = "Reviews", opinion = "Opinion"
    var id: String { rawValue }
}

struct Article: Identifiable, Hashable {
    let id: String
    var category: ArticleCategory
    var title: String
    var excerpt: String
    var author: String
    var publishedAt: Date
    var readMinutes: Int
    var body: [String]
    var isFeature = false

    var authorInitials: String {
        author.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }
}
