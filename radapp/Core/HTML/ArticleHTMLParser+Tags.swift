import Foundation

// what each html tag does to the parser
extension ArticleHTMLParser {
    // tags whose contents never belong in the article
    private static let skippedTags: Set<String> = ["script", "style", "noscript", "iframe", "svg", "button", "select"]

    mutating func handleTag(_ tag: HTMLTag) {
        let name = tag.name
        let isClosing = tag.isClosing

        // inside a skipped tag, wait for its matching close and ignore everything else
        if let skipTag {
            if name == skipTag {
                skipDepth += isClosing ? -1 : 1
                if skipDepth == 0 {
                    self.skipTag = nil
                }
            }
            return
        }
        // start skipping
        if !isClosing, Self.skippedTags.contains(name), !tag.isSelfClosing {
            skipTag = name
            skipDepth = 1
            return
        }

        switch (name, isClosing) {
        // paragraphs
        case ("p", false):
            // a <p> inside a quote or list item stays part of it
            if kind == nil || kind == .paragraph {
                begin(.paragraph)
            }
        case ("p", true):
            if kind == .paragraph {
                flush()
            }

        // headings, squeezed into three sizes
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

        // lists
        case ("ul", false):
            lists.append((ordered: false, count: 0))
        case ("ol", false):
            lists.append((ordered: true, count: 0))
        case ("ul", true), ("ol", true):
            flush()
            _ = lists.popLast()
        case ("li", false):
            // bullet, or the next number in a numbered list
            var marker = "•"
            if let last = lists.indices.last, lists[last].ordered {
                lists[last].count += 1
                marker = "\(lists[last].count)."
            }
            begin(.listItem(marker))

        // closing any block tag finishes the block
        case ("h1", true), ("h2", true), ("h3", true), ("h4", true), ("h5", true), ("h6", true),
             ("blockquote", true), ("figcaption", true), ("li", true):
            flush()

        // bold and italic count up on open, down on close
        case ("strong", _), ("b", _):
            boldDepth = max(0, boldDepth + (isClosing ? -1 : 1))
        case ("em", _), ("i", _):
            italicDepth = max(0, italicDepth + (isClosing ? -1 : 1))

        // links
        case ("a", false):
            // nil when there's no usable href, so the matching </a> still pops one
            let url = tag.attribute("href").flatMap { href in
                URL(string: HTMLEntities.decode(href), relativeTo: Self.baseURL)?.absoluteURL
            }
            links.append(url)
        case ("a", true):
            _ = links.popLast()

        // line break inside a block
        case ("br", _):
            if kind != nil {
                current += AttributedString("\n")
                lastWasSpace = true
            }

        case ("img", false):
            addImage(from: tag)

        // every other tag (div, span, ...) is ignored
        default:
            break
        }
    }

    private mutating func addImage(from tag: HTMLTag) {
        // squarespace puts the real url in data-src or data-image; skip inline data: images
        guard let raw = tag.attribute("data-src") ?? tag.attribute("data-image") ?? tag.attribute("src"),
              !raw.hasPrefix("data:"),
              let url = URL(string: HTMLEntities.decode(raw), relativeTo: Self.baseURL)?.absoluteURL
        else {
            return
        }

        // the url without ?format=..., so different sizes of one image count once
        let key = url.absoluteString.components(separatedBy: "?")[0]
        guard seenImages.insert(key).inserted else {
            return
        }
        // an image ends the text block before it
        flush()
        blocks.append(.image(url, caption: nil))
    }
}
