import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Background

struct ArtworkBackgroundLayer: View {
    let url: URL?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)
                // A blurred cover behind text costs contrast, so keep the background solid.
                if contrast == .standard {
                    artwork(size: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func artwork(size: CGSize) -> some View {
        CachedArtwork(url: url) { image in
            image.resizable().scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
                .blur(radius: 50)
                .scaleEffect(1.2)
                .opacity(0.3)
        } placeholder: {
            EmptyView()
        }
        LinearGradient(
            colors: [Color(.systemBackground).opacity(0.7), Color(.systemBackground).opacity(0.4), Color(.systemBackground).opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Connection badge

struct ConnectionQualityBadge: View {
    let connectivity: Connectivity
    @Environment(\.accentChoice) private var accent
    @State private var pulse = false

    private var color: Color {
        switch connectivity {
        case .good: return accent.color
        case .weak: return PlayerPalette.warn
        case .offline: return PlayerPalette.error
        }
    }

    private var text: String {
        switch connectivity {
        case .good: return "LIVE"
        case .weak: return "BUFFERING"
        case .offline: return "OFFLINE"
        }
    }

    private var isLive: Bool { connectivity == .good }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .opacity(isLive ? (pulse ? 1 : 0.5) : 1)
                .frame(width: 8, height: 8)
                .animation(isLive ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true) : .default, value: pulse)
                .onAppear { pulse = true }
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color, lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: connectivity)
    }
}

// MARK: - Artwork + metadata

struct GlowingArtwork: View {
    let url: URL?
    /// While no track is identified the cover shows the station logo, not track art.
    var showsStationLogo = false
    let isBusy: Bool
    let onDoubleTap: () -> Void
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(RadialGradient(
                    colors: [Color.primary.opacity(glow ? 0.09 : 0.045), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .padding(-4)

            Group {
                if showsStationLogo {
                    Image(.stationLogo).resizable().scaledToFill()
                } else {
                    ArtworkImage(url: url)
                }
            }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                .onTapGesture(count: 2, perform: onDoubleTap)

            if isBusy {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityLabel("Now playing artwork. Double-tap to open this track in a music app.")
    }
}

struct MetadataDisplay: View {
    let state: StreamState
    let title: String
    let artist: String?
    let onRetry: () -> Void

    var body: some View {
        Group {
            if case .failed(let message) = state {
                errorState(message)
            } else {
                VStack(spacing: 12) {
                    MarqueeText(title, font: .system(size: 24, weight: .bold), alignment: .center)
                        .foregroundStyle(.primary)
                        .animation(.default, value: title)
                    if let artist {
                        MarqueeText(artist, font: .system(size: 17), alignment: .center)
                            .foregroundStyle(.secondary)
                            .animation(.default, value: artist)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(PlayerPalette.error)
            Text(message)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry").fontWeight(.semibold)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Transport

struct VolumeControlBar: View {
    @State private var isMuted: Bool
    @State private var systemVolume = AVAudioSession.sharedInstance().outputVolume
    private let onMuteChange: (Bool) -> Void

    init(isMuted: Bool, onMuteChange: @escaping (Bool) -> Void) {
        _isMuted = State(initialValue: isMuted)
        self.onMuteChange = onMuteChange
    }

    private var isSilent: Bool { isMuted || systemVolume == 0 }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isSilent ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.fill.tertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            // Drives the device's system volume, so it stays in sync with the hardware buttons.
            SystemVolumeSlider()
                .frame(height: 34)
                .opacity(isMuted ? 0.4 : 1)
                .accessibilityLabel("Volume")
        }
        .onChange(of: isMuted) { _, newValue in onMuteChange(newValue) }
        .onReceive(AVAudioSession.sharedInstance().publisher(for: \.outputVolume)) { systemVolume = $0 }
    }
}

#if targetEnvironment(simulator)
/// `MPVolumeView` draws nothing in the Simulator, which has no device volume
/// to control, so the Simulator gets a plain slider for the stream's volume.
private struct SystemVolumeSlider: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @State private var volume: Float = 1

    var body: some View {
        Slider(value: $volume, in: 0...1)
            .tint(.primary)
            .onAppear { volume = player.volume }
            .onChange(of: volume) { _, newValue in player.volume = newValue }
    }
}
#else
private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.tintColor = .label
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#endif

struct PlaybackFAB: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.primary)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(.systemBackground))
            }
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            .scaleEffect(isPlaying ? 1 : 0.95)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

struct FavoriteToggleButton: View {
    let isFavorite: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var filledColor: Color {
        colorScheme == .dark ? PlayerPalette.favoriteFilled : PlayerPalette.error
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.primary)
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? filledColor : Color(.systemBackground))
            }
            .frame(width: 56, height: 56)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel("Like this track")
        .accessibilityValue(isFavorite ? "Liked" : "Not liked")
    }
}

struct SleepTimerButton: View {
    let endsAt: Date?
    /// End of the on-air show, offered as an extra option when known.
    let showEndsAt: Date?
    let onSet: (Date?) -> Void

    private static let durations = [5, 15, 30, 45, 60]

    var body: some View {
        Menu {
            if endsAt != nil {
                Button("Turn Off Timer", systemImage: "xmark", role: .destructive) { onSet(nil) }
            }
            if let showEndsAt, showEndsAt > .now {
                Button("End of Show", systemImage: "calendar") { onSet(showEndsAt) }
            }
            ForEach(Self.durations, id: \.self) { minutes in
                Button(minutes == 60 ? "1 hour" : "\(minutes) minutes") {
                    onSet(.now.addingTimeInterval(TimeInterval(minutes * 60)))
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary)
                Group {
                    if let endsAt, endsAt > .now {
                        VStack(spacing: 1) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 15))
                            Text(timerInterval: Date.now...endsAt, countsDown: true)
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 4)
                    } else {
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 20))
                    }
                }
                .foregroundStyle(Color(.systemBackground))
            }
            .frame(width: 56, height: 56)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .sensoryFeedback(.selection, trigger: endsAt)
        .accessibilityLabel("Sleep timer")
        .accessibilityValue(endsAt.map { "Stops at \($0.formatted(date: .omitted, time: .shortened))" } ?? "Off")
    }
}

// MARK: - Heart burst (favorited animation)

struct HeartBurstOverlay: View {
    let trigger: Int
    @State private var hearts: [Heart] = []

    private struct Heart: Identifiable {
        let id = UUID()
        var x: CGFloat
        var size: CGFloat
        var rotation: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(hearts) { heart in
                    FloatingHeart(size: heart.size, rotation: heart.rotation)
                        .position(x: heart.x, y: geo.size.height - 60)
                }
            }
            .onChange(of: trigger) { _, _ in burst(width: geo.size.width) }
        }
        .allowsHitTesting(false)
    }

    private func burst(width: CGFloat) {
        guard width > 1 else { return }
        for i in 0..<12 {
            let heart = Heart(
                x: .random(in: 24...max(25, width - 24)),
                size: .random(in: 16...26),
                rotation: .random(in: -15...15)
            )
            hearts.append(heart)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1 + Double(i) * 0.02) {
                hearts.removeAll { $0.id == heart.id }
            }
        }
    }
}

private struct FloatingHeart: View {
    let size: CGFloat
    let rotation: Double
    @State private var animate = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(PlayerPalette.error)
            .rotationEffect(.degrees(rotation))
            .offset(y: animate ? -420 : 0)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { animate = true }
            }
    }
}

// MARK: - Recently played

struct RecentlyPlayedHeader: View {
    let showsSeeAll: Bool
    let onSeeAll: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Recently played")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            if showsSeeAll {
                Button("See all", action: onSeeAll)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 4)
    }
}

struct RecentlyPlayedRow: View {
    let track: PlayedTrack
    let isLiked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: track.artworkURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(track.title, font: .system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                MarqueeText(track.artist, font: .system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLiked {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(PlayerPalette.error)
                    .accessibilityLabel("Liked")
            }
            Text(track.playedAt, style: .time)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
