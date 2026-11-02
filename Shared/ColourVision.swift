import SwiftUI

// MARK: - Colour vision

// the colour vision setting: a filter over the whole app for each type of colour blindness
// nonisolated means not tied to the main thread
nonisolated enum ColourVision: String, CaseIterable, Identifiable {
    case standard
    case protanomaly, protanopia
    case deuteranomaly, deuteranopia
    case tritanomaly, tritanopia
    case monochromacy

    // MARK: - Storage

    static let storageKey = "colourVision"
    // kept in the app group with the accent colour
    static let store = AccentChoice.store

    // MARK: - Display text

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .standard:
            "Standard"
        case .protanomaly:
            "Protanomaly"
        case .protanopia:
            "Protanopia"
        case .deuteranomaly:
            "Deuteranomaly"
        case .deuteranopia:
            "Deuteranopia"
        case .tritanomaly:
            "Tritanomaly"
        case .tritanopia:
            "Tritanopia"
        case .monochromacy:
            "Monochromacy"
        }
    }

    var summary: String {
        switch self {
        case .standard:
            "Full colour vision"
        case .protanomaly:
            "Red-weak"
        case .protanopia:
            "Red-blind"
        case .deuteranomaly:
            "Green-weak"
        case .deuteranopia:
            "Green-blind"
        case .tritanomaly:
            "Blue-weak"
        case .tritanopia:
            "Blue-blind"
        case .monochromacy:
            "No colour vision"
        }
    }

    // MARK: - Filter values

    // hue shift per type, picked by simulating each type's vision (Machado et al. 2009)
    fileprivate var hueShift: Angle {
        switch self {
        case .standard, .monochromacy:
            .zero
        case .protanomaly:
            .degrees(-50)
        case .protanopia, .deuteranomaly:
            .degrees(-55)
        case .deuteranopia:
            .degrees(-60)
        case .tritanomaly, .tritanopia:
            .degrees(75)
        }
    }

    // stronger colours so the shifted ones stand apart
    fileprivate var saturation: Double {
        switch self {
        case .standard, .monochromacy:
            1
        case .protanomaly, .protanopia, .deuteranomaly, .deuteranopia:
            1.6
        case .tritanomaly, .tritanopia:
            1.4
        }
    }

    // no hue left to separate, so plain greyscale
    fileprivate var grayscale: Double {
        if self == .monochromacy {
            return 1
        }
        return 0
    }
}

// MARK: - View modifier

extension View {
    // applies the filter to this view and everything in it; standard leaves colours as they are
    func colourVisionFilter(_ vision: ColourVision) -> some View {
        hueRotation(vision.hueShift)
            .saturation(vision.saturation)
            .grayscale(vision.grayscale)
    }

    // reads the saved setting, for sheets, which sit outside the filtered app
    func colourVisionFilter() -> some View {
        modifier(StoredColourVisionFilter())
    }
}

// MARK: - Stored filter

private struct StoredColourVisionFilter: ViewModifier {
    // @AppStorage property wrapper, saved in UserDefaults and redraws when it changes
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var vision: ColourVision = .standard

    func body(content: Content) -> some View {
        content.colourVisionFilter(vision)
    }
}
