import SwiftUI

// MARK: - Background

/// Full-bleed blurred artwork + dark gradient scrim behind the whole screen.
struct ArtworkBackgroundLayer: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        // Explicit frame + clipped() before blur: AsyncImage's
                        // intrinsic size otherwise leaks through scaledToFill,
                        // which both breaks the fill and makes blur invisible.
                        image.resizable().scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .blur(radius: 50)
                            .scaleEffect(1.2)
                            .opacity(0.3)
                    }
                }
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.4), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// Plain artwork fill used for the hero square and history rows. Always
/// sizes to the frame given by its parent (via GeometryReader) rather than
/// the image's own intrinsic size — see the note in `ArtworkBackgroundLayer`.
struct ArtworkImage: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.white.opacity(0.08)
                        Text("RM")
                            .font(.system(size: min(geo.size.width, geo.size.height) * 0.3, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

// MARK: - Top bar

struct ImmersiveTopBar: View {
    let connectivity: Connectivity
    let onFavorites: () -> Void
    let onStatistics: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Text("RADMON RADIO")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.white)
                ConnectionQualityBadge(connectivity: connectivity)
            }
            Spacer()
            HStack(spacing: 12) {
                TopBarIconButton(systemImage: "heart", action: onFavorites)
                    .accessibilityLabel("Liked songs")
                TopBarIconButton(systemImage: "chart.bar", action: onStatistics)
                    .accessibilityLabel("Listening statistics")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
    }
}

struct TopBarIconButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.15), in: Circle())
                .scaleEffect(pressed ? 0.85 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pressed)
    }
}

struct ConnectionQualityBadge: View {
    let connectivity: Connectivity
    @State private var pulse = false

    private var color: Color {
        switch connectivity {
        case .good: return PlayerPalette.live
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
    let isBusy: Bool
    let onDoubleTap: () -> Void
    @State private var glow = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(RadialGradient(
                    colors: [.white.opacity(glow ? 0.09 : 0.045), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .padding(-4)

            ArtworkImage(url: url)
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
    let nowPlaying: NowPlaying
    let onRetry: () -> Void

    var body: some View {
        Group {
            if case .failed(let message) = state {
                errorState(message)
            } else {
                VStack(spacing: 12) {
                    Text(nowPlaying.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .animation(.default, value: nowPlaying.title)
                    Text(nowPlaying.artist)
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .animation(.default, value: nowPlaying.artist)
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
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry").fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Transport

struct VolumeControlBar: View {
    @Binding var volume: Float
    @State private var lastVolume: Float = 1

    var body: some View {
        HStack(spacing: 16) {
            Button {
                if volume > 0 {
                    lastVolume = volume
                    volume = 0
                } else {
                    volume = lastVolume > 0 ? lastVolume : 1
                }
            } label: {
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(volume == 0 ? "Unmute" : "Mute")

            Slider(value: $volume, in: 0...1)
                .tint(.white)
                .accessibilityLabel("Volume")
        }
    }
}

struct PlaybackFAB: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.black)
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

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white)
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? PlayerPalette.favoriteFilled : .black)
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

struct RecentlyPlayedSection: View {
    let tracks: [PlayedTrack]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recently Played")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)

            if tracks.isEmpty {
                Text("Track history appears here once the station reports it.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(tracks) { track in
                        RecentlyPlayedRow(track: track)
                        if track.id != tracks.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, 24 + 48 + 12)
                        }
                    }
                }
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 40)
    }
}

private struct RecentlyPlayedRow: View {
    let track: PlayedTrack

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: track.artworkURL)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            Text(track.playedAt, style: .time)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}
