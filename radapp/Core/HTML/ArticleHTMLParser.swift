import Foundation

enum ArticleBlock: Hashable {
    case paragraph(AttributedString)
    case heading(AttributedString, level: Int)
    case quote(AttributedString)
    case listItem(AttributedString, marker: String)
    case image(URL, caption: AttributedString?)
}

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

    private enum BlockKind: Equatable {
        case paragraph, heading(Int), quote, listItem(String), caption
    }

    private static let skippedTags: Set<String> = ["script", "style", "noscript", "iframe", "svg", "button", "select"]

    private var blocks: [ArticleBlock] = []
    private var current = AttributedString()
    private var kind: BlockKind?
    private var boldDepth = 0
    private var italicDepth = 0
    private var links: [URL?] = []
    private var lists: [(ordered: Bool, count: Int)] = []
    private var skipTag: String?
    private var skipDepth = 0
    private var seenImages = Set<String>()
    private var lastWasSpace = true

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
                handleTag(html[html.index(after: index)..<close])
                index = html.index(after: close)
            } else {
                let next = html[index...].firstIndex(of: "<") ?? html.endIndex
                handleText(html[index..<next])
                index = next
            }
        }
        flush()
    }

    private mutating func handleTag(_ tag: Substring) {
        let isClosing = tag.hasPrefix("/")
        let name = String((isClosing ? tag.dropFirst() : tag).prefix { $0.isLetter || $0.isNumber }).lowercased()
        guard !name.isEmpty else { return }

        if let skipTag {
            if name == skipTag {
                skipDepth += isClosing ? -1 : 1
                if skipDepth == 0 { self.skipTag = nil }
            }
            return
        }
        if !isClosing, Self.skippedTags.contains(name), !tag.hasSuffix("/") {
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
            links.append(Self.attribute("href", in: tag).flatMap {
                URL(string: Self.decodeEntities($0), relativeTo: Self.baseURL)?.absoluteURL
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

    private mutating func handleText(_ text: Substring) {
        guard skipTag == nil else { return }

        var collapsed = ""
        for character in Self.decodeEntities(String(text)) {
            if character.isWhitespace {
                if !lastWasSpace {
                    collapsed.append(" ")
                    lastWasSpace = true
                }
            } else {
                collapsed.append(character)
                lastWasSpace = false
            }
        }
        guard !collapsed.isEmpty else { return }
        if kind == nil {
            guard !collapsed.allSatisfy(\.isWhitespace) else { return }
            kind = .paragraph
        }

        var run = AttributedString(collapsed)
        var intent = InlinePresentationIntent()
        if boldDepth > 0 { intent.insert(.stronglyEmphasized) }
        if italicDepth > 0 { intent.insert(.emphasized) }
        if !intent.isEmpty { run.inlinePresentationIntent = intent }
        if let link = links.last(where: { $0 != nil }) ?? nil { run.link = link }
        current += run
    }

    private mutating func addImage(from tag: Substring) {
        guard let raw = Self.attribute("data-src", in: tag)
                ?? Self.attribute("data-image", in: tag)
                ?? Self.attribute("src", in: tag),
              !raw.hasPrefix("data:"),
              let url = URL(string: Self.decodeEntities(raw), relativeTo: Self.baseURL)?.absoluteURL
        else { return }

        let key = url.absoluteString.components(separatedBy: "?")[0]
        guard seenImages.insert(key).inserted else { return }
        flush()
        blocks.append(.image(url, caption: nil))
    }

    private mutating func begin(_ newKind: BlockKind) {
        flush()
        kind = newKind
    }

    private mutating func flush() {
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

    private static func attribute(_ name: String, in tag: Substring) -> String? {
        for quote in ["\"", "'"] {
            guard let start = tag.range(of: " \(name)=\(quote)") else { continue }
            let rest = tag[start.upperBound...]
            if let end = rest.firstIndex(of: Character(quote)) { return String(rest[..<end]) }
        }
        return nil
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
    ]

    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        var index = string.startIndex
        while index < string.endIndex {
            if string[index] == "&",
               let semicolon = string[index...].prefix(10).firstIndex(of: ";"),
               let decoded = decodeEntity(string[string.index(after: index)..<semicolon]) {
                result += decoded
                index = string.index(after: semicolon)
            } else {
                result.append(string[index])
                index = string.index(after: index)
            }
        }
        return result
    }

    private static func decodeEntity(_ entity: Substring) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            return UInt32(entity.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String($0) }
        }
        if entity.hasPrefix("#") {
            return UInt32(entity.dropFirst()).flatMap(Unicode.Scalar.init).map { String($0) }
        }
        return namedEntities[String(entity)]
    }
}
