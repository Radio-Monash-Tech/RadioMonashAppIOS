import MediaAccessibility
import SwiftUI

// the caption size chosen in ios settings > accessibility > subtitles & captioning
enum CaptionStyle {
    // 1 is the standard size
    static var systemRelativeSize: CGFloat {
        MACaptionAppearanceGetRelativeCharacterSize(.user, nil)
    }

    // sent when the caption style changes in settings
    static let didChange = Notification.Name(kMACaptionAppearanceSettingsChangedNotification as String)
}

// the Aa menu's sizes; system follows the ios setting
enum CaptionTextSize: String, CaseIterable, Identifiable {
    case system, small, medium, large, extraLarge

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .system:
            "Match System"
        case .small:
            "Small"
        case .medium:
            "Medium"
        case .large:
            "Large"
        case .extraLarge:
            "Extra Large"
        }
    }

    // how much bigger or smaller than normal
    func scale(system: CGFloat) -> CGFloat {
        switch self {
        case .system:
            system
        case .small:
            0.85
        case .medium:
            1
        case .large:
            1.2
        case .extraLarge:
            1.45
        }
    }
}
