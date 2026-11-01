import Foundation

// turns squarespace article html into blocks the app can draw
struct ArticleHTMLParser {
    // relative links like "/events" are resolved against the station's site
    static let baseURL = URL(string: "https://www.radiomonash.online")!

    // the article as blocks, for ArticleView
    static func blocks(from html: String) -> [ArticleBlock] {
        var parser = ArticleHTMLParser()
        parser.run(html)
        return parser.blocks
    }

    // the article as plain text, for word counts and excerpts
    static func plainText(from html: String) -> String {
        blocks(from: html).compactMap { block -> String? in
            switch block {
            case .paragraph(let text), .heading(let text, _), .quote(let text), .listItem(let text, _):
                String(text.characters)
            case .image(_, let caption):
                // images only add their caption, if any
                caption.map { caption in
                    String(caption.characters)
                }
            }
        }
        .joined(separator: "\n\n")
    }

    // the kind of block currently being built
    enum BlockKind: Equatable {
        case paragraph, heading(Int), quote, listItem(String), caption
    }

    // Parsing state. Not private so the extension files can use it; the
    // private init means only the static functions above ever make a parser.
    var blocks: [ArticleBlock] = []
    // text of the block being built
    var current = AttributedString()
    var kind: BlockKind?
    // how many <strong>/<em> tags we're inside
    var boldDepth = 0
    var italicDepth = 0
    // open <a> tags, innermost last
    var links: [URL?] = []
    // open <ul>/<ol> lists, innermost last
    var lists: [(ordered: Bool, count: Int)] = []
    // a tag whose contents are ignored, e.g. <script>
    var skipTag: String?
    var skipDepth = 0
    // images already added, so none appear twice
    var seenImages = Set<String>()
    // used to collapse runs of spaces into one
    var lastWasSpace = true

    private init() {}

    // walks the html, handing each tag and each piece of text to the extensions
    private mutating func run(_ html: String) {
        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<" {
                // skip <!-- comments -->
                if html[index...].hasPrefix("<!--") {
                    guard let end = html.range(of: "-->", range: index..<html.endIndex) else {
                        break
                    }
                    index = end.upperBound
                    continue
                }
                // a tag runs up to the next ">"
                guard let close = html[index...].firstIndex(of: ">") else {
                    break
                }
                if let tag = HTMLTag(html[html.index(after: index)..<close]) {
                    handleTag(tag)
                }
                index = html.index(after: close)
            } else {
                // text runs up to the next "<"
                let next = html[index...].firstIndex(of: "<") ?? html.endIndex
                handleText(html[index..<next])
                index = next
            }
        }
        // finish whatever block is still open
        flush()
    }

    // finish the open block and start a new kind
    mutating func begin(_ newKind: BlockKind) {
        flush()
        kind = newKind
    }

    // Finishes the open block and adds it to `blocks`, unless it's empty.
    mutating func flush() {
        // reset for the next block, whichever way this function exits
        defer {
            current = AttributedString()
            kind = nil
            lastWasSpace = true
        }
        guard let kind else {
            return
        }

        // trim spaces from both ends
        var text = current
        while let first = text.characters.first, first.isWhitespace {
            text.characters.removeFirst()
        }
        while let last = text.characters.last, last.isWhitespace {
            text.characters.removeLast()
        }
        guard !text.characters.isEmpty else {
            return
        }

        switch kind {
        case .paragraph:
            blocks.append(.paragraph(text))
        case .heading(let level):
            blocks.append(.heading(text, level: level))
        case .quote:
            blocks.append(.quote(text))
        case .listItem(let marker):
            blocks.append(.listItem(text, marker: marker))
        case .caption:
            // a caption attaches to the image just before it
            if let last = blocks.indices.last, case .image(let url, nil) = blocks[last] {
                blocks[last] = .image(url, caption: text)
            }
        }
    }
}
