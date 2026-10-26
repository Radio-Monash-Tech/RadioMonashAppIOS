import SwiftUI

/// The Colour Vision setting in Settings › Accessibility. Each type of colour
/// blindness applies a filter over the whole app, like iOS's Colour Filters,
/// shifting colours that type confuses onto ones it can tell apart.
nonisolated enum ColourVision: String, CaseIterable, Identifiable {
    case standard
    case protanomaly, protanopia
    case deuteranomaly, deuteranopia
    case tritanomaly, tritanopia
    case monochromacy

    static let storageKey = "colourVision"
    /// Kept in the App Group alongside the accent colour.
    static let store = AccentChoice.store

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .protanomaly: "Protanomaly"
        case .protanopia: "Protanopia"
        case .deuteranomaly: "Deuteranomaly"
        case .deuteranopia: "Deuteranopia"
        case .tritanomaly: "Tritanomaly"
        case .tritanopia: "Tritanopia"
        case .monochromacy: "Monochromacy"
        }
    }

    var summary: String {
        switch self {
        case .standard: "Full colour vision"
        case .protanomaly: "Red-weak"
        case .protanopia: "Red-blind"
        case .deuteranomaly: "Green-weak"
        case .deuteranopia: "Green-blind"
        case .tritanomaly: "Blue-weak"
        case .tritanopia: "Blue-blind"
        case .monochromacy: "No colour vision"
        }
    }

    // Hue shift and saturation boost for each type, chosen by simulating that
    // type's vision (Machado et al. 2009) over colour pairs it typically confuses
    // and keeping the setting that best separates the worst pair. Red-green types
    // move reds toward yellow and greens toward blue; blue-yellow types the reverse.
    // Worst-pair ΔE improves from 9–26 to 44–57.

    fileprivate var hueShift: Angle {
        switch self {
        case .standard, .monochromacy: .zero
        case .protanomaly: .degrees(-50)
        case .protanopia, .deuteranomaly: .degrees(-55)
        case .deuteranopia: .degrees(-60)
        case .tritanomaly, .tritanopia: .degrees(75)
        }
    }

    fileprivate var saturation: Double {
        switch self {
        case .standard, .monochromacy: 1
        case .protanomaly, .protanopia, .deuteranomaly, .deuteranopia: 1.6
        case .tritanomaly, .tritanopia: 1.4
        }
    }

    // There's no hue left to separate, so the app shows plainly in greyscale and
    // meaning comes from brightness, shapes and labels.
    fileprivate var grayscale: Double {
        self == .monochromacy ? 1 : 0
    }
}

extension View {
    /// Applies the Colour Vision filter to this view and everything inside it,
    /// artwork included. The modifiers stay in place at their identity values
    /// for Standard, so switching types doesn't reset any view state.
    func colourVisionFilter(_ vision: ColourVision) -> some View {
        hueRotation(vision.hueShift)
            .saturation(vision.saturation)
            .grayscale(vision.grayscale)
    }

    /// Reads the stored setting, for sheets: they're presented outside the
    /// filtered root, so their content applies the filter itself.
    func colourVisionFilter() -> some View {
        modifier(StoredColourVisionFilter())
    }
}

private struct StoredColourVisionFilter: ViewModifier {
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var vision: ColourVision = .standard

    func body(content: Content) -> some View {
        content.colourVisionFilter(vision)
    }
}
