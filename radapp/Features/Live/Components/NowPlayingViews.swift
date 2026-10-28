import SwiftUI

struct GlowingArtwork: View {
    let url: URL?
    /// While no track is identified the cover shows the station logo, not track art.
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
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityLabel("Now playing artwork. Double-tap to open this track in a music app.")
    }
}

struct MetadataDisplay: View {
    let state: StreamState
    let title: String
    let artist: String?
    let onRetry: () -> Void

    var body: some View {
        Group {
            if case .failed(let message) = state {
                errorState(message)
            } else {
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
            }
        }
        .padding(.horizontal, 32)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(PlayerPalette.error)
            Text(message)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry").fontWeight(.semibold)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
        }
    }
}
