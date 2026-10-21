import Foundation

// The text between a tag's `<` and `>`, e.g. `a href="/events"` or `/p`.
struct HTMLTag {
    let name: String
    let isClosing: Bool
    // Written as `<br/>`, so there's no closing tag to wait for.
    let isSelfClosing: Bool
    private let source: Substring

    init?(_ source: Substring) {
        isClosing = source.hasPrefix("/")
        name = String((isClosing ? source.dropFirst() : source).prefix { $0.isLetter || $0.isNumber }).lowercased()
        guard !name.isEmpty else { return nil }
        isSelfClosing = source.hasSuffix("/")
        self.source = source
    }

    // The value of `name="…"` or `name='…'`, still entity-encoded.
    func attribute(_ name: String) -> String? {
        for quote in ["\"", "'"] {
            guard let start = source.range(of: " \(name)=\(quote)") else { continue }
            let rest = source[start.upperBound...]
            if let end = rest.firstIndex(of: Character(quote)) { return String(rest[..<end]) }
        }
        return nil
    }
}
