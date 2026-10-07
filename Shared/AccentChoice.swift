import SwiftUI
import UIKit

/// The app-wide accent colour picked in Settings › Customization.
nonisolated enum AccentChoice: String, CaseIterable, Identifiable {
    case blue, purple, pink, red, orange, yellow, green, graphite

    static let storageKey = "accentColor"
    /// Kept in the App Group so the Live Activity matches the app.
    static let store = UserDefaults(suiteName: WidgetArtwork.appGroup) ?? .standard

    static var current: AccentChoice {
        store.string(forKey: storageKey).flatMap(AccentChoice.init) ?? .blue
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .graphite: "Graphite"
        }
    }

    /// System colours, so each one adapts to dark mode and Increase Contrast.
    var uiColor: UIColor {
        switch self {
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .pink: .systemPink
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .graphite: .systemGray
        }
    }

    var color: Color { Color(uiColor: uiColor) }

    /// Text and icons drawn on top of the accent.
    var onColor: Color {
        self == .yellow ? .black : .white
    }
}

extension EnvironmentValues {
    @Entry var accentChoice: AccentChoice = .blue
}
