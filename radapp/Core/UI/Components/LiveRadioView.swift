import SwiftUI

struct LiveRadioView: View {

    @StateObject private var model = RadioPlayerModel()
    @State private var showingPlatformSheet = false
    @State private var path = NavigationPath()
    @State private var likeBurstTrigger = 0

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArtworkBackgroundLayer(url: model.nowPlaying.artworkURL)

                VStack(spacing: 0) {
                    ImmersiveTopBar(
                        connectivity: model.connectivity,
                        onFavorites: { path.append(LiveRoute.liked) },
                        onStatistics: { path.append(LiveRoute.statistics) }
                    )

                    GeometryReader { viewport in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                playerSection
                                    .frame(minHeight: viewport.size.height)
                                RecentlyPlayedSection(tracks: model.history)
                            }
                        }
                    }
                }

                HeartBurstOverlay(trigger: likeBurstTrigger)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPlatformSheet) {
                PlatformSheet(track: model.nowPlaying)
            }
            .navigationDestination(for: LiveRoute.self) { destination(for: $0) }
        }
        .task { model.prepareSession() }
        .preferredColorScheme(.dark)
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
        .background(LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: Destinations

    @ViewBuilder
    private func destination(for route: LiveRoute) -> some View {
        switch route {
        case .liked:
            placeholder("Liked Songs")
        case .statistics:
            placeholder("Listening Statistics")
        case .history:
            placeholder("History")
        }
    }

    private func placeholder(_ title: String) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text(title).foregroundStyle(.white)
        }
        .navigationTitle(title)
    }
}

#Preview {
    LiveRadioView()
}
