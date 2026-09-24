import SwiftUI
import SwiftData

enum LiveRoute: Hashable { case liked, statistics, history }

struct LiveRadioView: View {

    @EnvironmentObject private var model: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Query private var favourites: [FavouriteTrack]
    @State private var showingPlatformSheet = false
    @State private var path = NavigationPath()
    @State private var likeBurstTrigger = 0

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArtworkBackgroundLayer(url: model.nowPlaying.artworkURL)

                GeometryReader { viewport in
                    List {
                        playerSection
                            .frame(minHeight: viewport.size.height)
                            .plainListRow()

                        RecentlyPlayedHeader(showsSeeAll: !model.history.isEmpty) {
                            path.append(LiveRoute.history)
                        }
                        .plainListRow()

                        playedEarlierRows

                        Color.clear
                            .frame(height: 40)
                            .plainListRow()
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }

                HeartBurstOverlay(trigger: likeBurstTrigger)
            }
            .navigationTitle("Radio Monash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionQualityBadge(connectivity: model.connectivity)
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: LiveRoute.liked) {
                        Label("Liked Songs", systemImage: "heart")
                    }
                    NavigationLink(value: LiveRoute.statistics) {
                        Label("Listening Statistics", systemImage: "chart.bar")
                    }
                }
            }
            .sheet(isPresented: $showingPlatformSheet) {
                PlatformSheet(track: model.nowPlaying)
            }
            .navigationDestination(for: LiveRoute.self) { destination(for: $0) }
        }
    }

    @ViewBuilder
    private var playedEarlierRows: some View {
        if model.history.isEmpty {
            Text("Track history appears here once the station reports it.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .plainListRow()
        } else {
            let likedKeys = Set(favourites.map(\.key))
            ForEach(model.history) { track in
                let isLiked = likedKeys.contains(track.favouriteKey)
                RecentlyPlayedRow(track: track, isLiked: isLiked)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(track.id == model.history.last?.id ? .hidden : .visible, edges: .bottom)
                    .listRowSeparator(.hidden, edges: .top)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 24 + 48 + 12 }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            model.toggleLike(track, showName: schedule.onAir(at: track.playedAt)?.series.title)
                        } label: {
                            Label(isLiked ? "Unlike" : "Like",
                                  systemImage: isLiked ? "heart.slash.fill" : "heart.fill")
                        }
                        .tint(isLiked ? .gray : PlayerPalette.error)
                    }
            }
        }
    }

    private var playerSection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            GlowingArtwork(
                url: model.nowPlaying.artworkURL,
                isBusy: model.isBusy,
                onDoubleTap: { showingPlatformSheet = true }
            )
            Spacer().frame(height: 32)
            MetadataDisplay(state: model.state, nowPlaying: model.nowPlaying, onRetry: model.retry)

            Spacer(minLength: 0)

            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            VolumeControlBar(initialVolume: model.volume) { model.volume = $0 }
            HStack(spacing: 16) {
                PlaybackFAB(isPlaying: model.state == .playing, action: model.togglePlayback)
                FavoriteToggleButton(isFavorite: model.isCurrentTrackLiked) {
                    model.toggleLike()
                    if model.isCurrentTrackLiked { likeBurstTrigger += 1 }
                }
                .disabled(!model.canLikeCurrentTrack)
                .opacity(model.canLikeCurrentTrack ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(LinearGradient(colors: [.clear, Color(.systemBackground).opacity(0.3)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: Destinations

    @ViewBuilder
    private func destination(for route: LiveRoute) -> some View {
        switch route {
        case .liked:
            LikedSongsView()
        case .statistics:
            ListeningStatisticsView()
        case .history:
            PlayHistoryView()
        }
    }
}

#Preview {
    LiveRadioView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(for: FavouriteTrack.self, inMemory: true)
}

private extension View {
    func plainListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
