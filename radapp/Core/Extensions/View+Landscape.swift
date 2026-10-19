import SwiftUI

extension EnvironmentValues {
    /// True when an iPhone is held sideways. iPhone landscape is the only iPhone
    /// layout with a compact vertical size class, so no orientation notifications are needed.
    var isLandscapePhone: Bool { verticalSizeClass == .compact }
}

extension View {
    /// Centres content at a comfortable reading width in landscape, so lines of text
    /// don't stretch across the whole screen. Full width in portrait.
    func readableWidthInLandscape() -> some View {
        modifier(ReadableWidthInLandscape())
    }
}

private struct ReadableWidthInLandscape: ViewModifier {
    @Environment(\.isLandscapePhone) private var isLandscape

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: isLandscape ? 620 : .infinity)
            .frame(maxWidth: .infinity)
    }
}
