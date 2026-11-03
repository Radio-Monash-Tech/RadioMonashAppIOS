import Foundation

// the text between a tag's `<` and `>`, e.g. `a href="/events"` or `/p`.
struct HTMLTag {
    // lowercased, e.g. "a" or "p"
    let name: String
    // true for `/p`
    let isClosing: Bool
    // Written as `<br/>`, so there's no closing tag to wait for.
    let isSelfClosing: Bool
    // the whole tag text, kept for reading attributes
    private let source: Substring

    // nil when there's no tag name, e.g. `<!DOCTYPE>` or `< >`
    init?(_ source: Substring) {
        isClosing = source.hasPrefix("/")
        // drop the "/" of a closing tag
        let afterSlash = isClosing ? source.dropFirst() : source
        // the name is the letters and numbers at the start
        let rawName = afterSlash.prefix { character in
            character.isLetter || character.isNumber
        }
        name = String(rawName).lowercased()
        guard !name.isEmpty else {
            return nil
        }
        isSelfClosing = source.hasSuffix("/")
        self.source = source
    }

    // the value of `name="…"` or `name='…'`, still entity-encoded.
    func attribute(_ name: String) -> String? {
        // try double quotes, then single quotes
        for quote in ["\"", "'"] {
            guard let start = source.range(of: " \(name)=\(quote)") else {
                continue
            }
            // everything after the opening quote
            let rest = source[start.upperBound...]
            // up to the closing quote
            if let end = rest.firstIndex(of: Character(quote)) {
                return String(rest[..<end])
            }
        }
        return nil
    }
}
