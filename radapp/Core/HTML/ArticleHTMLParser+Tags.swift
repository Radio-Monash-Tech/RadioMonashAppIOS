import Foundation

extension ArticleHTMLParser {
    private static let skippedTags: Set<String> = ["script", "style", "noscript", "iframe", "svg", "button", "select"]

    mutating func handleTag(_ tag: HTMLTag) {
        let name = tag.name
        let isClosing = tag.isClosing

        if let skipTag {
            if name == skipTag {
                skipDepth += isClosing ? -1 : 1
                if skipDepth == 0 { self.skipTag = nil }
            }
            return
        }
        if !isClosing, Self.skippedTags.contains(name), !tag.isSelfClosing {
            skipTag = name
            skipDepth = 1
            return
        }

        switch (name, isClosing) {
        case ("p", false):
            if kind == nil || kind == .paragraph { begin(.paragraph) }
        case ("p", true):
            if kind == .paragraph { flush() }
        case ("h1", false), ("h2", false):
            begin(.heading(1))
        case ("h3", false):
            begin(.heading(2))
        case ("h4", false), ("h5", false), ("h6", false):
            begin(.heading(3))
        case ("blockquote", false):
            begin(.quote)
        case ("figcaption", false):
            begin(.caption)
        case ("ul", false):
            lists.append((ordered: false, count: 0))
        case ("ol", false):
            lists.append((ordered: true, count: 0))
        case ("ul", true), ("ol", true):
            flush()
            _ = lists.popLast()
        case ("li", false):
            var marker = "•"
            if let last = lists.indices.last, lists[last].ordered {
                lists[last].count += 1
                marker = "\(lists[last].count)."
            }
            begin(.listItem(marker))
        case ("h1", true), ("h2", true), ("h3", true), ("h4", true), ("h5", true), ("h6", true),
             ("blockquote", true), ("figcaption", true), ("li", true):
            flush()
        case ("strong", _), ("b", _):
            boldDepth = max(0, boldDepth + (isClosing ? -1 : 1))
        case ("em", _), ("i", _):
            italicDepth = max(0, italicDepth + (isClosing ? -1 : 1))
        case ("a", false):
            links.append(tag.attribute("href").flatMap {
                URL(string: HTMLEntities.decode($0), relativeTo: Self.baseURL)?.absoluteURL
            })
        case ("a", true):
            _ = links.popLast()
        case ("br", _):
            if kind != nil {
                current += AttributedString("\n")
                lastWasSpace = true
            }
        case ("img", false):
            addImage(from: tag)
        default:
            break
        }
    }

    private mutating func addImage(from tag: HTMLTag) {
        guard let raw = tag.attribute("data-src") ?? tag.attribute("data-image") ?? tag.attribute("src"),
              !raw.hasPrefix("data:"),
              let url = URL(string: HTMLEntities.decode(raw), relativeTo: Self.baseURL)?.absoluteURL
        else { return }

        let key = url.absoluteString.components(separatedBy: "?")[0]
        guard seenImages.insert(key).inserted else { return }
        flush()
        blocks.append(.image(url, caption: nil))
    }
}
