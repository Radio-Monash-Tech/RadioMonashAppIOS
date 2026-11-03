import Foundation

// what the text between tags does to the parser
extension ArticleHTMLParser {
    mutating func handleText(_ text: Substring) {
        // ignore text inside <script>, <style> ...
        guard skipTag == nil else {
            return
        }

        // decode entities and collapse spaces and new lines into single spaces, like a browser
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
        guard !collapsed.isEmpty else {
            return
        }
        // text outside any block starts a paragraph, unless it's only spaces
        if kind == nil {
            guard !collapsed.allSatisfy(\.isWhitespace) else {
                return
            }
            kind = .paragraph
        }

        // style the text with whatever bold, italic and link tags are open
        var run = AttributedString(collapsed)
        var intent = InlinePresentationIntent()
        if boldDepth > 0 {
            intent.insert(.stronglyEmphasized)
        }
        if italicDepth > 0 {
            intent.insert(.emphasized)
        }
        if !intent.isEmpty {
            run.inlinePresentationIntent = intent
        }
        // the innermost link that has a url
        if let link = links.last(where: { link in link != nil }) ?? nil {
            run.link = link
        }
        current += run
    }
}
