import SwiftUI

enum LiveRoute: Hashable { case liked, statistics, history }

struct LiveRadioView: View {

    @EnvironmentObject private var model: RadioPlayerModel
    @State private var showingPlatformSheet = false
    @State private var path = NavigationPath()
    @State private var likeBurstTrigger = 0

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArtworkBackgroundLayer(url: model.nowPlaying.artworkURL)

                GeometryReader { viewport in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            playerSection
                                .frame(minHeight: viewport.size.height)
                            RecentlyPlayedSection(tracks: model.history)
                        }
                    }
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
            VolumeControlBar(volume: $model.volume)
            HStack(spacing: 16) {
                PlaybackFAB(isPlaying: model.state == .playing, action: model.togglePlayback)
                FavoriteToggleButton(isFavorite: model.isCurrentTrackLiked) {
                    if !model.isCurrentTrackLiked { likeBurstTrigger += 1 }
                    model.toggleLike()
                }
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
}
