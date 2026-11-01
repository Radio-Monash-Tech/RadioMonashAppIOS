import Foundation

// decodes HTML entities such as `&amp;`, `&rsquo;`, `&#8217;` and `&#x2019;`.
enum HTMLEntities {
    // entities written by name, e.g. &amp; → &
    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201D}", "ldquo": "\u{201C}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
    ]

    static func decode(_ string: String) -> String {
        // nothing to decode
        guard string.contains("&") else {
            return string
        }
        var result = ""
        var index = string.startIndex
        // walk through one character at a time
        while index < string.endIndex {
            // an "&", a ";" within 10 characters, and a known entity in between
            if string[index] == "&",
               let semicolon = string[index...].prefix(10).firstIndex(of: ";"),
               let decoded = decodeEntity(string[string.index(after: index)..<semicolon]) {
                result += decoded
                // carry on after the ";"
                index = string.index(after: semicolon)
            } else {
                // an ordinary character, copy it across
                result.append(string[index])
                index = string.index(after: index)
            }
        }
        return result
    }

    // the text between "&" and ";", e.g. "amp", "#8217" or "#x2019"
    private static func decodeEntity(_ entity: Substring) -> String? {
        // hex number, e.g. #x2019
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            guard let number = UInt32(entity.dropFirst(2), radix: 16),
                  let scalar = Unicode.Scalar(number)
            else {
                return nil
            }
            return String(scalar)
        }
        // decimal number
        if entity.hasPrefix("#") {
            guard let number = UInt32(entity.dropFirst()),
                  let scalar = Unicode.Scalar(number)
            else {
                return nil
            }
            return String(scalar)
        }
        // a name, e.g. amp
        return named[String(entity)]
    }
}
