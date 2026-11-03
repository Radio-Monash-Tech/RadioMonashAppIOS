import SwiftUI
import SwiftData

// MARK: - Routes

// screens the live tab can push
enum LiveRoute: Hashable {
    case history
}

// MARK: - Live view

// the live tab: artwork, titles, controls and live captions
struct LiveRadioView: View {

    // MARK: - State

    // @EnvironmentObject property wrapper, reads a shared object passed down from a parent view
    @EnvironmentObject private var model: RadioPlayerModel
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var showingPlatformSheet = false
    @State private var showingRecent = false
    @State private var path = NavigationPath()
    // bumped to play the heart animation
    @State private var likeBurstTrigger = 0
    @State private var showingCaptionSetup = false
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.isLandscapePhone) private var isLandscape

    // MARK: - Body

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
                    ConnectionQualityBadge(connectivity: badgeConnectivity)
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
                // "see all" closes the sheet and opens the full history
                RecentlyPlayedSheet {
                    showingRecent = false
                    path.append(LiveRoute.history)
                }
                .colourVisionFilter()
            }
            .navigationDestination(for: LiveRoute.self) { route in
                destination(for: route)
            }
        }
    }

    // MARK: - Layout

    // offline when the stream failed, even if song info still loads
    private var badgeConnectivity: Connectivity {
        if case .failed = model.state {
            return .offline
        }
        return model.connectivity
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

    // captions replace the artwork, titles and volume while they're on
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

    // artwork or captions on the left, titles and controls on the right
    private var landscapePlayer: some View {
        HStack(spacing: 0) {
            if showsCaptions {
                captionsView
            } else {
                artwork
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if !showsCaptions {
                    metadata
                }
                Spacer(minLength: 0)
                controls
            }
        }
    }

    // MARK: - Artwork

    private var artwork: some View {
        GlowingArtwork(
            url: model.nowPlaying.artworkURL,
            showsStationLogo: model.showsStationLogo,
            isBusy: model.isBusy,
            // double tap opens the streaming links, once the song is known
            onDoubleTap: {
                if model.isIdentifiedTrack {
                    showingPlatformSheet = true
                }
            }
        )
    }

    // MARK: - Captions

    private var captions: CaptionCoordinator {
        model.captions
    }

    private var showsCaptions: Bool {
        captions.isSupported && captions.isEnabled
    }

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

    // turns captions on or off, or explains why it can't yet
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

    // the Aa menu: caption size and music captions
    private var captionOptions: some View {
        Menu {
            Picker("Caption Size", selection: Binding(
                get: {
                    captions.textSize
                },
                set: { size in
                    captions.textSize = size
                }
            )) {
                ForEach(CaptionTextSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            Toggle(isOn: Binding(
                get: {
                    captions.captionsMusic
                },
                set: { isOn in
                    captions.captionsMusic = isOn
                }
            )) {
                Label("Caption Music", systemImage: "music.note")
            }
        } label: {
            Text("Aa")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Caption Options")
    }

    // MARK: - Titles and controls

    private var metadata: some View {
        MetadataDisplay(title: model.displayTitle, artist: model.displayArtist)
    }

    // volume, sleep timer, play, like and the utility row
    private var controls: some View {
        VStack(spacing: 20) {
            if !showsCaptions {
                VolumeControlBar(isMuted: model.isMuted) { isMuted in
                    model.isMuted = isMuted
                }
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
                    // hearts only when liking, not unliking
                    if model.isCurrentTrackLiked {
                        likeBurstTrigger += 1
                    }
                }
                .disabled(!model.canLikeCurrentTrack)
                .opacity(model.canLikeCurrentTrack ? 1 : 0.4)
            }
            PlayerUtilityRow(
                captionsOn: showsCaptions,
                captionsAvailable: captions.isSupported,
                showingRecent: showingRecent,
                onCaptions: toggleCaptions,
                onRecent: {
                    showingRecent = true
                }
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(LinearGradient(colors: [.clear, Color(.systemBackground).opacity(0.3)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: - Navigation

    // @ViewBuilder lets each branch return a different view
    @ViewBuilder
    private func destination(for route: LiveRoute) -> some View {
        switch route {
        case .history:
            PlayHistoryView()
        }
    }
}

// MARK: - Preview

// #Preview macro, shows this view in Xcode's canvas
#Preview {
    LiveRadioView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(for: FavouriteTrack.self, inMemory: true)
}

// MARK: - Toolbar helpers

private extension ToolbarContent {
    // ios 26 puts toolbar items on glass; hide it, older ios has none
    // @ToolbarContentBuilder lets this return several toolbar items
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        // #available checks the ios version while the app runs
        if #available(iOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
