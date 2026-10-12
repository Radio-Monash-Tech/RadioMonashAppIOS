import SwiftUI

struct ArtworkImage: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            CachedArtwork(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: { isLoading in
                ZStack {
                    Color(.tertiarySystemFill)
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("RM")
                            .font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .heavy))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}
