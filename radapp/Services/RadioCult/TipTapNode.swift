import Foundation

/// A node of the TipTap rich-text JSON RadioCult uses for show descriptions.
struct TipTapNode: Decodable {
    let type: String
    let text: String?
    let marks: [TipTapMark]?
    let content: [TipTapNode]?
}

struct TipTapMark: Decodable {
    struct Attributes: Decodable {
        let href: String?
    }

    let type: String
    let attrs: Attributes?
}

extension TipTapNode {
    var attributedText: AttributedString {
        switch type {
        case "text":
            var run = AttributedString(text ?? "")
            var intent = InlinePresentationIntent()
            for mark in marks ?? [] {
                switch mark.type {
                case "bold": intent.insert(.stronglyEmphasized)
                case "italic": intent.insert(.emphasized)
                case "code": intent.insert(.code)
                case "strike": intent.insert(.strikethrough)
                case "link": run.link = mark.attrs?.href.flatMap(URL.init(string:))
                default: break
                }
            }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            return run
        case "hardBreak":
            return AttributedString("\n")
        case "listItem":
            return AttributedString("• ") + children(separatedBy: "\n")
        case "doc", "blockquote":
            return children(separatedBy: "\n\n")
        case "bulletList", "orderedList":
            return children(separatedBy: "\n")
        default:
            return children(separatedBy: "")
        }
    }

    private func children(separatedBy separator: String) -> AttributedString {
        let parts = (content ?? []).map(\.attributedText).filter { !$0.characters.isEmpty }
        var result = AttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 { result += AttributedString(separator) }
            result += part
        }
        return result
    }
}
