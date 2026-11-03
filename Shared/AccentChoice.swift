import SwiftUI
import UIKit

// MARK: - Accent choice

// the app-wide accent colour picked in settings
// nonisolated means not tied to the main thread
nonisolated enum AccentChoice: String, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green, graphite

    // MARK: - Storage

    static let storageKey = "accentColor"
    // kept in the app group so the widget matches the app
    static let store = UserDefaults(suiteName: WidgetArtwork.appGroup) ?? .standard

    // the saved choice, for code outside a view (the widget)
    static var current: AccentChoice {
        // guard exits early if the check fails
        guard let raw = store.string(forKey: storageKey), let choice = AccentChoice(rawValue: raw) else {
            return .blue
        }
        return choice
    }

    // MARK: - Display

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .blue:
            "Blue"
        case .purple:
            "Purple"
        case .pink:
            "Pink"
        case .red:
            "Red"
        case .orange:
            "Orange"
        case .yellow:
            "Yellow"
        case .green:
            "Green"
        case .graphite:
            "Graphite"
        }
    }

    // MARK: - Colours

    // system colours, so each adapts to dark mode and increase contrast
    var uiColor: UIColor {
        switch self {
        case .blue:
            .systemBlue
        case .purple:
            .systemPurple
        case .pink:
            .systemPink
        case .red:
            .systemRed
        case .orange:
            .systemOrange
        case .yellow:
            .systemYellow
        case .green:
            .systemGreen
        case .graphite:
            .systemGray
        }
    }

    var color: Color {
        Color(uiColor: uiColor)
    }

    // text and icons drawn on top of the accent
    var onColor: Color {
        if self == .yellow {
            return .black
        }
        return .white
    }
}

// MARK: - Environment

extension EnvironmentValues {
    // read with @Environment(\.accentChoice)
    // @Entry macro, adds a custom value to the SwiftUI environment
    @Entry var accentChoice: AccentChoice = .blue
}
