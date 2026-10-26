import SwiftUI

enum Brand {
    static let background = Color(.systemBackground)
    static let elevated = Color(.secondarySystemBackground)
    static let artworkFill = Color(.tertiarySystemFill)
    static let glass = Color(.tertiarySystemFill)

    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
}

enum PlayerPalette {
    static let warn = Color.contrastAdaptive(
        standard: UIColor(red: 1.0, green: 0.651, blue: 0.149, alpha: 1),         // #FFA726
        highContrastLight: UIColor(red: 0.706, green: 0.325, blue: 0.035, alpha: 1), // #B45309
        highContrastDark: UIColor(red: 1.0, green: 0.8, blue: 0.502, alpha: 1)       // #FFCC80
    )
    static let error = Color.contrastAdaptive(
        standard: UIColor(red: 0.937, green: 0.329, blue: 0.314, alpha: 1),         // #EF5350
        highContrastLight: UIColor(red: 0.776, green: 0.157, blue: 0.157, alpha: 1), // #C62828
        highContrastDark: UIColor(red: 1.0, green: 0.541, blue: 0.502, alpha: 1)     // #FF8A80
    )
    static let favoriteFilled = Color(red: 0.545, green: 0, blue: 0)      // #8B0000
}

private extension Color {
    /// Swaps to a stronger shade when Increase Contrast is on, whether set in iOS
    /// or forced by the app's Accessibility setting.
    static func contrastAdaptive(standard: UIColor, highContrastLight: UIColor, highContrastDark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            guard traits.accessibilityContrast == .high else { return standard }
            return traits.userInterfaceStyle == .dark ? highContrastDark : highContrastLight
        })
    }
}
