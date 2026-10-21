import Foundation

// One chunk of an article, ready for `ArticleView` to draw.
enum ArticleBlock: Hashable {
    case paragraph(AttributedString)
    case heading(AttributedString, level: Int)
    case quote(AttributedString)
    case listItem(AttributedString, marker: String)
    case image(URL, caption: AttributedString?)
}
