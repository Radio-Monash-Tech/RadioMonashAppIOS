import SwiftUI

enum Brand {
    static let accent = Color(red: 0.176, green: 0.827, blue: 0.435) // #2DD36F
    static let onAccent = Color(red: 0.016, green: 0.078, blue: 0.039) // #04140A

    static let background = Color(.systemBackground)
    static let elevated = Color(.secondarySystemBackground)
    static let artworkFill = Color(.tertiarySystemFill)
    static let glass = Color(.tertiarySystemFill)

    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
}

enum PlayerPalette {
    static let live = Color(red: 0.114, green: 0.725, blue: 0.329)       // #1DB954
    static let warn = Color(red: 1.0, green: 0.651, blue: 0.149)          // #FFA726
    static let error = Color(red: 0.937, green: 0.329, blue: 0.314)       // #EF5350
    static let favoriteFilled = Color(red: 0.545, green: 0, blue: 0)      // #8B0000

    static func platformColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "spotify": return live
        case "apple music": return Color(red: 1.0, green: 0.306, blue: 0.420)   // #FF4E6B
        case "youtube music", "youtube": return Color(red: 1.0, green: 0, blue: 0)
        case "bandcamp": return Color(red: 0.114, green: 0.635, blue: 0.761)    // #1DA1C2
        case "deezer": return Color(red: 0.635, green: 0.220, blue: 1.0)        // #A238FF
        default: return Color(white: 0.4)
        }
    }
}
