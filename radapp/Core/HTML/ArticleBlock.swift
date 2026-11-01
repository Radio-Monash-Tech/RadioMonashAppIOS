import Foundation

// One chunk of an article, ready for `ArticleView` to draw.
enum ArticleBlock: Hashable {
    case paragraph(AttributedString)
    // level 1 is the biggest
    case heading(AttributedString, level: Int)
    case quote(AttributedString)
    // marker is "•" or "1.", "2." ...
    case listItem(AttributedString, marker: String)
    // caption comes from the figcaption after the image
    case image(URL, caption: AttributedString?)
}
