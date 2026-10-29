import SwiftUI
import SwiftData

enum LiveRoute: Hashable { case history, transcript }

struct LiveRadioView: View {

    @EnvironmentObject private var model: RadioPlayerModel
    @State private var showingPlatformSheet = false
    @State private var showingRecent = false
    @State private var path = NavigationPath()
    @State private var likeBurstTrigger = 0
    @State private var showingCaptionSetup = false
    @Environment(\.isLandscapePhone) private var isLandscape

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArtworkBackgroundLayer(url: model.showsStationLogo ? nil : model.nowPlaying.artworkURL)

                playerSection

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
                if showsCaptions {
                    ToolbarItem(placement: .topBarTrailing) {
                        captionOptions
                    }
                }
            }
            .sheet(isPresented: $showingCaptionSetup) {
                CaptionSetupSheet(captions: captions)
                    .presentationDetents([.large])
                    .colourVisionFilter()
            }
            .sheet(isPresented: $showingPlatformSheet) {
                PlatformSheet(track: model.nowPlaying)
                    .colourVisionFilter()
            }
            .sheet(isPresented: $showingRecent) {
                RecentlyPlayedSheet {
                    showingRecent = false
                    path.append(LiveRoute.history)
                }
                .colourVisionFilter()
            }
            .navigationDestination(for: LiveRoute.self) { destination(for: $0) }
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
        .animation(.snappy, value: showsCaptions)
    }

    // While captions are on they take the place of the artwork, titles and volume.
    private var portraitPlayer: some View {
        VStack(spacing: 0) {
            if showsCaptions {
                captionsView
            } else {
                Spacer(minLength: 0)
                artwork
                Spacer().frame(height: 32)
                metadata
                Spacer(minLength: 0)
            }
            controls
        }
    }

    // Artwork (or captions) on the left, titles and controls on the right.
    private var landscapePlayer: some View {
        HStack(spacing: 0) {
            if showsCaptions {
                captionsView
            } else {
                artwork
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if !showsCaptions { metadata }
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
            // Nothing to look up until RadioCult names the song.
            onDoubleTap: { if model.isIdentifiedTrack { showingPlatformSheet = true } }
        )
    }

    // MARK: Captions

    private var captions: CaptionCoordinator { model.captions }

    private var showsCaptions: Bool { captions.isSupported && captions.isEnabled }

    private var captionsView: some View {
        LiveCaptionsView(
            captions: captions,
            title: model.displayTitle,
            artist: model.displayArtist,
            artworkURL: model.nowPlaying.artworkURL,
            showsStationLogo: model.showsStationLogo
        )
        .transition(.opacity)
    }

    private func toggleCaptions() {
        switch captions.availability {
        case .unsupported(let reason):
            SystemPresenter.alert(title: "Live Captions Aren't Available", message: reason)
        case .checking:
            SystemPresenter.alert(title: "Live Captions Are Getting Ready", message: "Try again in a moment.")
        default:
            if captions.isEnabled {
                captions.isEnabled = false
            } else if captions.needsSetup {
                showingCaptionSetup = true
            } else {
                captions.isEnabled = true
            }
        }
    }

    /// The Aa menu: caption size, lyrics on or off, and the transcript.
    private var captionOptions: some View {
        Menu {
            Picker("Caption Size", selection: Binding(
                get: { captions.textSize },
                set: { captions.textSize = $0 }
            )) {
                ForEach(CaptionTextSize.allCases) { Text($0.label).tag($0) }
            }
            Toggle(isOn: Binding(
                get: { captions.captionsMusic },
                set: { captions.captionsMusic = $0 }
            )) {
                Label("Caption Music", systemImage: "music.note")
            }
            Button {
                path.append(LiveRoute.transcript)
            } label: {
                Label("Open Transcript", systemImage: "text.page")
            }
        } label: {
            Text("Aa")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Caption Options")
    }

    private var metadata: some View {
        MetadataDisplay(state: model.state, title: model.displayTitle, artist: model.displayArtist, onRetry: model.retry)
    }

    private var controls: some View {
        VStack(spacing: 20) {
            if !showsCaptions {
                VolumeControlBar(isMuted: model.isMuted) { model.isMuted = $0 }
            }
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
            PlayerUtilityRow(
                captionsOn: showsCaptions,
                captionsAvailable: captions.isSupported,
                showingRecent: showingRecent,
                onCaptions: toggleCaptions,
                onRecent: { showingRecent = true }
            )
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
        case .transcript:
            TranscriptView()
        }
    }
}

#Preview {
    LiveRadioView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(for: FavouriteTrack.self, inMemory: true)
}

private extension ToolbarContent {
    // iOS 26 puts toolbar items on a shared glass background; earlier versions have none to hide.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
