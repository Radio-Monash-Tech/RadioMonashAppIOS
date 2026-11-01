import SwiftUI

extension EnvironmentValues {
    
    // compact when in portrait
    var isLandscapePhone: Bool {
        verticalSizeClass == .compact
    }
}

extension View {
    // centres content at a comfortable reading width in landscape
    func readableWidthInLandscape() -> some View {
        modifier(ReadableWidthInLandscape())
    }
}

// used through readableWidthInLandscape() above
private struct ReadableWidthInLandscape: ViewModifier {
    @Environment(\.isLandscapePhone) private var isLandscape

    func body(content: Content) -> some View {
        content
            // at most 620 wide in landscape, no limit in portrait
            .frame(maxWidth: isLandscape ? 620 : .infinity)
            // fill the width so the column sits in the middle
            .frame(maxWidth: .infinity)
    }
}
