import SwiftUI

// light, dark or follow the phone
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .system:
            "Match System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    // nil means follow the phone
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
