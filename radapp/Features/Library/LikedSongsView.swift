import SwiftUI
import SwiftData

struct LikedSongsView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @Query(sort: \FavouriteTrack.savedAt, order: .reverse) private var tracks: [FavouriteTrack]

    var body: some View {
        Group {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "No Liked Songs",
                    systemImage: "heart",
                    description: Text("Tap the heart on the Live player and the track will be saved here.")
                )
            } else {
                List {
                    ForEach(tracks) { track in
                        LikedSongRow(track: track)
                    }
                    .onDelete { offsets in
                        for index in offsets { player.unlike(tracks[index]) }
                    }
                }
            }
        }
        .navigationTitle("Liked Songs")
        .toolbar {
            if !tracks.isEmpty { EditButton() }
        }
    }
}

private struct LikedSongRow: View {
    let track: FavouriteTrack

    private var subtitle: String {
        [track.artist, track.showName].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: track.artworkURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(track.title, font: .body)
                MarqueeText(subtitle, font: .subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(track.savedAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { LikedSongsView() }
        .environmentObject(RadioPlayerModel())
        .modelContainer(for: FavouriteTrack.self, inMemory: true)
}
