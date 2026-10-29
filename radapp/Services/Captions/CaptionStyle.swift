import MediaAccessibility
import SwiftUI

/// The caption size the listener chose in Settings > Accessibility >
/// Subtitles & Captioning, which "Match System" follows.
enum CaptionStyle {
    /// 1 is the standard size.
    static var systemRelativeSize: CGFloat {
        MACaptionAppearanceGetRelativeCharacterSize(.user, nil)
    }

    /// Posted when the listener changes their caption style in Settings.
    static let didChange = Notification.Name(kMACaptionAppearanceSettingsChangedNotification as String)
}

/// The Aa button's sizes. System follows the size chosen in Settings.
enum CaptionTextSize: String, CaseIterable, Identifiable {
    case system, small, medium, large, extraLarge

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "Match System"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    func scale(system: CGFloat) -> CGFloat {
        switch self {
        case .system: system
        case .small: 0.85
        case .medium: 1
        case .large: 1.2
        case .extraLarge: 1.45
        }
    }
}
