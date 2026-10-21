import Foundation

extension ArticleHTMLParser {
    mutating func handleText(_ text: Substring) {
        guard skipTag == nil else { return }

        var collapsed = ""
        for character in HTMLEntities.decode(String(text)) {
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
}
