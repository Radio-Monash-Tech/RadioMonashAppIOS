import SwiftUI

// square cover image with a spinner or "RM" fallback
struct ArtworkImage: View {
    let url: URL?

    var body: some View {

        // automatically expand and occupy the screen based on the screen size
        GeometryReader { geo in
            CachedArtwork(url: url) { image in
                // fill the box without stretching
                image.resizable().scaledToFill()
            } placeholder: { isLoading in
                ZStack {
                    Color(.tertiarySystemFill)
                    if isLoading {
                        ProgressView()
                    } else {
                        // fallback logo, 30% of the box's shorter side
                        Text("RM")
                            .font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .heavy))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            // cut off the edges that scaledToFill pushes out
            .clipped()
        }
    }
}
