import SwiftUI

/// Compact now-playing bar docked above the tab bar on every tab.
/// Tapping it jumps to the Live tab; the button toggles playback in place.
struct MiniPlayer: View {
    @EnvironmentObject private var player: RadioPlayerModel
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: player.nowPlaying.artworkURL)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(player.nowPlaying.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(player.liveShow?.billing ?? player.nowPlaying.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: player.togglePlayback) {
                Group {
                    if player.isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: player.state == .playing ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.state == .playing ? "Pause" : "Play")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the live player")
    }
}
