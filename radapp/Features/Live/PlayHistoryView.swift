import SwiftUI

struct PlayHistoryView: View {
    @EnvironmentObject private var player: RadioPlayerModel

    var body: some View {
        Group {
            if player.history.isEmpty {
                ContentUnavailableView(
                    "No Tracks Yet",
                    systemImage: "clock",
                    description: Text("Tracks appear here once the station reports them.")
                )
            } else {
                List(player.history) { track in
                    HStack(spacing: 12) {
                        ArtworkImage(url: track.artworkURL)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).lineLimit(1)
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(track.playedAt, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Played Earlier")
    }
}
