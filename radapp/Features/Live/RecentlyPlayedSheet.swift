import SwiftUI
import SwiftData

/// Recently played, opened from the list button under the player. The song
/// on air comes first, then what RadioCult reports played before it. Tap a
/// heart (or swipe) to like a song; swipe to share it.
struct RecentlyPlayedSheet: View {
    let onSeeAll: () -> Void

    @EnvironmentObject private var model: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Query private var favourites: [FavouriteTrack]
    @State private var sharingTrack: ShareableTrack?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentChoice) private var accent

    var body: some View {
        NavigationStack {
            List {
                if model.isIdentifiedTrack || model.liveShow != nil {
                    nowRow
                }
                let likedKeys = Set(favourites.map(\.key))
                ForEach(model.history) { track in
                    historyRow(track, isLiked: likedKeys.contains(track.favouriteKey))
                }
                if !model.history.isEmpty {
                    Section {
                        Button("See Full History", action: onSeeAll)
                            .foregroundStyle(accent.color)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if model.history.isEmpty, !model.isIdentifiedTrack, model.liveShow == nil {
                    ContentUnavailableView(
                        "Nothing Played Yet",
                        systemImage: "music.note.list",
                        description: Text("Tracks appear here once the station reports them.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Recently Played").font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .trackShareSheet(for: $sharingTrack)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Rows

    /// The song on air, or the show when a host is on and no song is named.
    @ViewBuilder
    private var nowRow: some View {
        if model.isIdentifiedTrack {
            let track = model.nowPlaying
            TrackRow(
                title: track.title,
                artist: track.artist,
                artworkURL: track.artworkURL,
                trailing: .now,
                isLiked: model.isCurrentTrackLiked,
                onToggleLike: model.canLikeCurrentTrack ? { model.toggleLike() } : nil
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                likeAction(isLiked: model.isCurrentTrackLiked) { model.toggleLike() }
                shareAction(ShareableTrack(title: track.title, artist: track.artist))
            }
        } else if let show = model.liveShow {
            TrackRow(title: show.name, artist: "On air now", artworkURL: nil, showsStationLogo: true,
                     trailing: .now, isLiked: false, onToggleLike: nil)
        }
    }

    private func historyRow(_ track: PlayedTrack, isLiked: Bool) -> some View {
        let toggle = {
            model.toggleLike(track, showName: schedule.onAir(at: track.playedAt)?.series.title)
        }
        return TrackRow(
            title: track.title,
            artist: track.artist,
            artworkURL: track.artworkURL,
            trailing: .time(track.playedAt),
            isLiked: isLiked,
            onToggleLike: toggle
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            likeAction(isLiked: isLiked, toggle: toggle)
            shareAction(track.shareable)
        }
    }

    private func likeAction(isLiked: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            Label(isLiked ? "Unlike" : "Like", systemImage: isLiked ? "heart.slash.fill" : "heart.fill")
        }
        .tint(isLiked ? .gray : PlayerPalette.error)
    }

    private func shareAction(_ track: ShareableTrack) -> some View {
        Button {
            sharingTrack = track
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .tint(.orange)
    }
}

private struct TrackRow: View {
    enum Trailing {
        case now
        case time(Date)
    }

    let title: String
    let artist: String
    let artworkURL: URL?
    var showsStationLogo = false
    let trailing: Trailing
    let isLiked: Bool
    /// Nil hides the heart (nothing to like, such as a show with no song named).
    let onToggleLike: (() -> Void)?
    @Environment(\.accentChoice) private var accent

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if showsStationLogo {
                    Image(.stationLogo).resizable().scaledToFill()
                } else {
                    ArtworkImage(url: artworkURL)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(title, font: .body.weight(.medium))
                MarqueeText(artist, font: .subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)

            Group {
                switch trailing {
                case .now:
                    Text("Now").font(.caption.weight(.bold)).foregroundStyle(accent.color)
                case .time(let date):
                    Text(date, style: .time).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()

            if let onToggleLike {
                Button(action: onToggleLike) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? PlayerPalette.error : .secondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "Unlike \(title)" : "Like \(title)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
