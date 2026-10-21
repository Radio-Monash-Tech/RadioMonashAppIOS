import Foundation

// Decodes HTML entities such as `&amp;`, `&rsquo;`, `&#8217;` and `&#x2019;`.
enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
    ]

    static func decode(_ string: String) -> String {
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
        return named[String(entity)]
    }
}
