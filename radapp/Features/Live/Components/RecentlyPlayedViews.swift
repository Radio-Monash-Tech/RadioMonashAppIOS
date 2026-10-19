import SwiftUI

struct RecentlyPlayedHeader: View {
    let showsSeeAll: Bool
    let onSeeAll: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recently played")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            if showsSeeAll {
                Button("See all", action: onSeeAll)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 4)
    }
}

struct RecentlyPlayedRow: View {
    let track: PlayedTrack
    let isLiked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: track.artworkURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(track.title, font: .system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                MarqueeText(track.artist, font: .system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLiked {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(PlayerPalette.error)
                    .accessibilityLabel("Liked")
            }
            Text(track.playedAt, style: .time)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
