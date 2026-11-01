import SwiftUI

// the big cover art with a soft pulsing glow
struct GlowingArtwork: View {
    let url: URL?
    // the station logo instead of cover art
    var showsStationLogo = false
    let isBusy: Bool
    let onDoubleTap: () -> Void
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(RadialGradient(
                    colors: [Color.primary.opacity(glow ? 0.09 : 0.045), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .padding(-4)

            Group {
                if showsStationLogo {
                    Image(.stationLogo).resizable().scaledToFill()
                } else {
                    ArtworkImage(url: url)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .onTapGesture(count: 2, perform: onDoubleTap)

            // dimmed with a spinner while connecting
            if isBusy {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityLabel("Now playing artwork. Double-tap to open this track in a music app.")
    }
}

// the title and artist under the artwork
struct MetadataDisplay: View {
    let title: String
    let artist: String?

    var body: some View {
        VStack(spacing: 12) {
            MarqueeText(title, font: .title2.bold(), alignment: .center)
                .foregroundStyle(.primary)
                .animation(.default, value: title)
            if let artist {
                MarqueeText(artist, font: .body, alignment: .center)
                    .foregroundStyle(.secondary)
                    .animation(.default, value: artist)
            }
        }
        .padding(.horizontal, 32)
    }
}
