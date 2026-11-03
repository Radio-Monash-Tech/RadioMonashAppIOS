import SwiftUI

// the small now-playing bar above the tab bar
struct MiniPlayer: View {
    // @EnvironmentObject property wrapper, reads a shared object passed down from a parent view
    @EnvironmentObject private var player: RadioPlayerModel
    // jumps to the live tab
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if player.showsStationLogo {
                    Image(.stationLogo).resizable().scaledToFill()
                } else {
                    ArtworkImage(url: player.nowPlaying.artworkURL)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                MarqueeText(player.displayTitle, font: .subheadline.weight(.semibold))
                if let artist = player.displayArtist {
                    MarqueeText(artist, font: .caption)
                        .foregroundStyle(.secondary)
                }
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
        // tapping anywhere but the play button opens the player
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the live player")
    }
}
