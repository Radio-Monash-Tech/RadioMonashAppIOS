import SwiftUI
import SwiftData

struct PlayHistoryView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Query private var favourites: [FavouriteTrack]
    @State private var sharingTrack: ShareableTrack?

    var body: some View {
        Group {
            if player.history.isEmpty {
                ContentUnavailableView(
                    "No Tracks Yet",
                    systemImage: "clock",
                    description: Text("Tracks appear here once the station reports them.")
                )
            } else {
                let likedKeys = Set(favourites.map(\.key))
                List(player.history) { track in
                    let isLiked = likedKeys.contains(track.favouriteKey)
                    HStack(spacing: 12) {
                        ArtworkImage(url: track.artworkURL)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            MarqueeText(track.title, font: .body)
                            MarqueeText(track.artist, font: .subheadline)
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
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            player.toggleLike(track, showName: schedule.onAir(at: track.playedAt)?.series.title)
                        } label: {
                            Label(isLiked ? "Unlike" : "Like",
                                  systemImage: isLiked ? "heart.slash.fill" : "heart.fill")
                        }
                        .tint(isLiked ? .gray : PlayerPalette.error)

                        Button {
                            sharingTrack = track.shareable
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .trackShareSheet(for: $sharingTrack)
        .navigationTitle("Played Earlier")
    }
}
