import SwiftUI
import SwiftData

enum LiveRoute: Hashable { case history }

struct LiveRadioView: View {

    @EnvironmentObject private var model: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Query private var favourites: [FavouriteTrack]
    @State private var showingPlatformSheet = false
    @State private var sharingTrack: ShareableTrack?
    @State private var path = NavigationPath()
    @State private var likeBurstTrigger = 0
    @Environment(\.isLandscapePhone) private var isLandscape

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArtworkBackgroundLayer(url: model.showsStationLogo ? nil : model.nowPlaying.artworkURL)

                GeometryReader { viewport in
                    List {
                        playerSection
                            // In landscape, cap the height too so the artwork shrinks to fit above the tab bar.
                            .frame(minHeight: viewport.size.height,
                                   maxHeight: isLandscape ? viewport.size.height : nil)
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
                .hidingSharedBackground()
            }
            .sheet(isPresented: $showingPlatformSheet) {
                PlatformSheet(track: model.nowPlaying)
            }
            .trackShareSheet(for: $sharingTrack)
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
                        
                        // share button
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

    private var playerSection: some View {
        Group {
            if isLandscape {
                landscapePlayer
            } else {
                portraitPlayer
            }
        }
        .animation(.snappy, value: isLandscape)
    }

    private var portraitPlayer: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            artwork
            Spacer().frame(height: 32)
            metadata

            Spacer(minLength: 0)

            controls
        }
    }

    /// Artwork on the left, titles and controls on the right.
    private var landscapePlayer: some View {
        HStack(spacing: 0) {
            artwork
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                metadata
                Spacer(minLength: 0)
                controls
            }
        }
    }

    private var artwork: some View {
        GlowingArtwork(
            url: model.nowPlaying.artworkURL,
            showsStationLogo: model.showsStationLogo,
            isBusy: model.isBusy,
            onDoubleTap: { showingPlatformSheet = true }
        )
    }

    private var metadata: some View {
        MetadataDisplay(state: model.state, title: model.displayTitle, artist: model.displayArtist, onRetry: model.retry)
    }

    private var controls: some View {
        VStack(spacing: 20) {
            VolumeControlBar(isMuted: model.isMuted) { model.isMuted = $0 }
            HStack(spacing: 16) {
                SleepTimerButton(
                    endsAt: model.sleepTimerEndsAt,
                    showEndsAt: model.currentShowEndsAt,
                    onSet: model.setSleepTimer(endingAt:)
                )
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

private extension ToolbarContent {
    /// iOS 26 puts toolbar items on a shared glass background; earlier versions have none to hide.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
