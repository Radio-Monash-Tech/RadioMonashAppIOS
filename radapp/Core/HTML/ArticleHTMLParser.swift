import Foundation

struct ArticleHTMLParser {
    static let baseURL = URL(string: "https://www.radiomonash.online")!

    static func blocks(from html: String) -> [ArticleBlock] {
        var parser = ArticleHTMLParser()
        parser.run(html)
        return parser.blocks
    }

    static func plainText(from html: String) -> String {
        blocks(from: html).compactMap { block -> String? in
            switch block {
            case .paragraph(let text), .heading(let text, _), .quote(let text), .listItem(let text, _):
                String(text.characters)
            case .image(_, let caption):
                caption.map { String($0.characters) }
            }
        }
        .joined(separator: "\n\n")
    }

    enum BlockKind: Equatable {
        case paragraph, heading(Int), quote, listItem(String), caption
    }

    // Parsing state. Not private so the extension files can use it; the
    // private init means only the static functions above ever make a parser.
    var blocks: [ArticleBlock] = []
    var current = AttributedString()
    var kind: BlockKind?
    var boldDepth = 0
    var italicDepth = 0
    var links: [URL?] = []
    var lists: [(ordered: Bool, count: Int)] = []
    var skipTag: String?
    var skipDepth = 0
    var seenImages = Set<String>()
    var lastWasSpace = true

    private init() {}

    private mutating func run(_ html: String) {
        var index = html.startIndex
        while index < html.endIndex {
            if html[index] == "<" {
                if html[index...].hasPrefix("<!--") {
                    guard let end = html.range(of: "-->", range: index..<html.endIndex) else { break }
                    index = end.upperBound
                    continue
                }
                guard let close = html[index...].firstIndex(of: ">") else { break }
                if let tag = HTMLTag(html[html.index(after: index)..<close]) { handleTag(tag) }
                index = html.index(after: close)
            } else {
                let next = html[index...].firstIndex(of: "<") ?? html.endIndex
                handleText(html[index..<next])
                index = next
            }
        }
        flush()
    }

    mutating func begin(_ newKind: BlockKind) {
        flush()
        kind = newKind
    }

    // Finishes the open block and adds it to `blocks`, unless it's empty.
    mutating func flush() {
        defer {
            current = AttributedString()
            kind = nil
            lastWasSpace = true
        }
        guard let kind else { return }

        var text = current
        while let first = text.characters.first, first.isWhitespace { text.characters.removeFirst() }
        while let last = text.characters.last, last.isWhitespace { text.characters.removeLast() }
        guard !text.characters.isEmpty else { return }

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
            if let last = blocks.indices.last, case .image(let url, nil) = blocks[last] {
                blocks[last] = .image(url, caption: text)
            }
        }
    }
}
