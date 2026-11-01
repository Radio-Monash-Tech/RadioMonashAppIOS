import SwiftUI
import SwiftData

// every song the user hearted, newest first
struct LikedSongsView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @Query(sort: \FavouriteTrack.savedAt, order: .reverse) private var tracks: [FavouriteTrack]
    // the song being shared, opens the share sheet
    @State private var sharingTrack: ShareableTrack?

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
                            // custom swipe actions replace onDelete's, so delete is added back here
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    player.unlike(track)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                // share song
                                Button {
                                    sharingTrack = track.shareable
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .tint(.orange)
                            }
                    }
                    // the delete buttons in edit mode
                    .onDelete { offsets in
                        for index in offsets {
                            player.unlike(tracks[index])
                        }
                    }
                }
            }
        }
        .trackShareSheet(for: $sharingTrack)
        .navigationTitle("Liked Songs")
        .toolbar {
            if !tracks.isEmpty {
                EditButton()
            }
        }
    }
}

// cover, title, artist · show, and the date it was liked
private struct LikedSongRow: View {
    let track: FavouriteTrack

    // "Artist · Show", or just the artist if there was no show
    private var subtitle: String {
        [track.artist, track.showName]
            .compactMap { part in
                part
            }
            .joined(separator: " · ")
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
        // voiceover reads the row as one item
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        LikedSongsView()
    }
    .environmentObject(RadioPlayerModel())
    .modelContainer(for: FavouriteTrack.self, inMemory: true)
}
