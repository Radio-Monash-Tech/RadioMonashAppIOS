import SwiftUI

/// "Listen on" bottom sheet, styled to match the Android reference app's
/// `PlatformLinksBottomSheet` (dark card, brand-colored platform badges).
struct PlatformSheet: View {
    let track: NowPlaying
    @Environment(\.dismiss) private var dismiss

    private let platforms = ["Spotify", "Apple Music", "YouTube Music", "Bandcamp", "Deezer"]

    var body: some View {
        VStack(spacing: 8) {
            Text("Listen on")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text(track.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Text(track.artist)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                ForEach(platforms, id: \.self) { name in
                    Button {
                        dismiss()
                    } label: {
                        PlatformRow(name: name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(PlayerPalette.sheetBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

private struct PlatformRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(PlayerPalette.platformColor(name))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "music.note").foregroundStyle(.white))

            Text(name)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
