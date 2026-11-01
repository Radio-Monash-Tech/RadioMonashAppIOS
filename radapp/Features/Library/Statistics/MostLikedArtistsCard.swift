import SwiftUI

struct MostLikedArtistsCard: View {
    let artists: [ListeningStats.ArtistLikes]
    @Environment(\.accentChoice) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader("Most-liked artists") {
                // opens through LibraryView's LibraryRoute destination
                NavigationLink("Liked Songs", value: LibraryRoute.liked)
                    .font(.subheadline)
                    .foregroundStyle(accent.color)
            }

            ForEach(artists) { artist in
                HStack(spacing: 14) {
                    Text(artist.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(artist.count) liked")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .statsCard()
    }
}
