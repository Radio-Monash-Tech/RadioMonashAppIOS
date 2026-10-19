import SwiftUI

struct ArtworkBackgroundLayer: View {
    let url: URL?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)
                // A blurred cover behind text costs contrast, so keep the background solid.
                if contrast == .standard {
                    artwork(size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func artwork(size: CGSize) -> some View {
        CachedArtwork(url: url) { image in
            image.resizable().scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .blur(radius: 50)
                .scaleEffect(1.2)
                .opacity(0.3)
        } placeholder: {
            EmptyView()
        }
        LinearGradient(
            colors: [Color(.systemBackground).opacity(0.7), Color(.systemBackground).opacity(0.4), Color(.systemBackground).opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
