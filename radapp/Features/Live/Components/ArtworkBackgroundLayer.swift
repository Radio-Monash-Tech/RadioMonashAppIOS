import SwiftUI

// the blurred cover art behind the live player
struct ArtworkBackgroundLayer: View {
    let url: URL?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)
                // keep it solid with increased contrast, a blur behind text costs contrast
                if contrast == .standard {
                    artwork(size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    // the cover, blurred and faded, with a gradient on top
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
