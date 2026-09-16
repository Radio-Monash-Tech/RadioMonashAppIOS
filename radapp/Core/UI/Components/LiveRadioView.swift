import SwiftUI

struct LiveRadioView: View {

    @StateObject private var model = RadioPlayerModel()
    @State private var showingPlatformSheet = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) {
                    artwork
                    billing
                    trackTitles
                    progressBar
                    volumeSlider
                    transport
                    playedEarlier
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Brand.background)
            .navigationTitle("")
            .toolbar { toolbar }
            .safeAreaInset(edge: .top) { connectivityBanner }
            .overlay { if case .failed(let message) = model.state { failure(message) } }
            .overlay { if model.isBusy { connecting } }
            .sheet(isPresented: $showingPlatformSheet) {
                PlatformSheet(track: model.nowPlaying)
            }
            .refreshable { await model.refreshMetadata() }
        }
        .task { model.prepareSession() }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 9) {
                Text("RADMON RADIO")
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(1)
                    .lineLimit(1)
                onAirPill
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink(value: LiveRoute.liked) {
                Image(systemName: "heart")
            }
            .accessibilityLabel("Liked songs")

            NavigationLink(value: LiveRoute.statistics) {
                Image(systemName: "chart.bar")
            }
            .accessibilityLabel("Listening statistics")
        }
    }

    private var onAirPill: some View {
        Group {
            if model.isOnAir {
                HStack(spacing: 5) {
                    PulsingDot()
                    Text("LIVE")
                        .font(.system(size: 9.5, weight: .bold))
                        .kerning(0.95)
                }
                .foregroundStyle(Brand.accent)
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(Brand.accent.opacity(0.16), in: Capsule())
            } else {
                Text("OFF AIR")
                    .font(.system(size: 9.5, weight: .bold))
                    .kerning(0.95)
                    .foregroundStyle(Brand.secondaryText)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 9)
                    .background(Brand.elevated, in: Capsule())
            }
        }
        .accessibilityLabel(model.isOnAir ? "On air now" : "Off air, default playlist")
    }

    // MARK: Sections

    private var artwork: some View {
        ArtworkView(url: model.nowPlaying.artworkURL, side: 300, corner: 18)
            .shadow(color: .black.opacity(0.4), radius: 22, y: 20)
            .padding(.top, 26)
            .accessibilityHidden(true)
    }

    private var billing: some View {
        HStack(spacing: 6) {
            if let show = model.liveShow {
                Text("ON AIR")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.9)
                    .foregroundStyle(Brand.accent)
                Text("·").foregroundStyle(Brand.tertiaryText)
                Text(show.billing)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Brand.secondaryText)
            } else {
                Text("Default playlist · unattended")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Brand.secondaryText)
            }
        }
        .padding(.top, 9)
        .frame(height: 18)
    }

    private var trackTitles: some View {
        VStack(spacing: 5) {
            Text(model.nowPlaying.title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
            Text(model.nowPlaying.artist)
                .font(.system(size: 17))
                .foregroundStyle(Brand.secondaryText)
        }
        .padding(.top, 14)
        .animation(.default, value: model.nowPlaying)
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.glass)
                    Capsule()
                        .fill(Brand.primaryText)
                        .frame(width: geo.size.width * model.progress)
                }
            }
            .frame(height: 5)

            HStack {
                Text(model.elapsedLabel)
                Spacer()
                Text(model.remainingLabel)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Brand.tertiaryText)
        }
        .padding(.top, 22)
        .accessibilityHidden(true) // live stream: position isn't actionable
    }

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
            Slider(value: $model.volume, in: 0...1)
                .tint(Brand.primaryText)
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.system(size: 13))
        .foregroundStyle(Brand.tertiaryText)
        .padding(.top, 20)
        .accessibilityLabel("Volume")
    }

    private var transport: some View {
        HStack(spacing: 26) {
            CircleButton(size: 48) {
                showingPlatformSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Open this track in a music app")

            Button {
                model.togglePlayback()
            } label: {
                ZStack {
                    Circle().fill(Brand.primaryText)
                    Image(systemName: model.state == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Brand.background)
                }
                .frame(width: 74, height: 74)
                .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
            }
            .accessibilityLabel(model.state == .playing ? "Pause" : "Play")

            CircleButton(size: 48, tinted: model.isCurrentTrackLiked) {
                model.toggleLike()
            } label: {
                Image(systemName: model.isCurrentTrackLiked ? "heart.fill" : "heart")
            }
            .accessibilityLabel("Like this track")
            .accessibilityValue(model.isCurrentTrackLiked ? "Liked" : "Not liked")
        }
        .padding(.top, 26)
        .sensoryFeedback(.selection, trigger: model.isCurrentTrackLiked)
    }

    private var playedEarlier: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Played earlier")
                    .font(.system(size: 19, weight: .semibold))
                Spacer()
                NavigationLink("See all", value: LiveRoute.history)
                    .font(.system(size: 14))
                    .tint(Brand.accent)
            }

            if model.history.isEmpty {
                Text("Track history appears here once the station reports it.")
                    .font(.system(size: 13))
                    .foregroundStyle(Brand.secondaryText)
                    .padding(.bottom, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(model.history) { track in
                            VStack(alignment: .leading, spacing: 7) {
                                ArtworkView(url: track.artworkURL, side: 104, corner: 10)
                                Text(track.title)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                                Text(track.playedAt, style: .time)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Brand.tertiaryText)
                            }
                            .frame(width: 104, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(.top, 30)
    }

    // MARK: States

    @ViewBuilder
    private var connectivityBanner: some View {
        if let message = model.connectivity.banner {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                Text(message)
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var connecting: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Connecting to stream…")
                .font(.system(size: 13))
                .foregroundStyle(Brand.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Stream unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") { model.retry() }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
        }
        .background(Brand.background)
    }
}

#Preview {
    LiveRadioView()
}
