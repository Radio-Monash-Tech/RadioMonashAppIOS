import SwiftUI

/// Captions in place of the artwork while CC is on: a small now-playing row,
/// then what's been said or sung, grouped by speaker. The newest line sits
/// at the bottom with a cursor while it's still being heard; older lines
/// fade towards the top.
struct LiveCaptionsView: View {
    let captions: CaptionCoordinator
    let title: String
    let artist: String?
    let artworkURL: URL?
    let showsStationLogo: Bool

    @State private var systemSize = CaptionStyle.systemRelativeSize
    @ScaledMetric(relativeTo: .title3) private var hostSize: CGFloat = 20
    @ScaledMetric(relativeTo: .title2) private var lyricSize: CGFloat = 25
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var scale: CGFloat { captions.textSize.scale(system: systemSize) }

    var body: some View {
        VStack(spacing: 0) {
            nowPlayingRow
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ZStack {
                captionScroll
                if captions.groups.isEmpty {
                    emptyState
                }
            }

            footnote
                .padding(.horizontal, 24)
                .padding(.top, 14)
        }
        .onReceive(NotificationCenter.default.publisher(for: CaptionStyle.didChange)) { _ in
            systemSize = CaptionStyle.systemRelativeSize
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { systemSize = CaptionStyle.systemRelativeSize }
        }
    }

    // MARK: Now playing

    private var nowPlayingRow: some View {
        HStack(spacing: 12) {
            Group {
                if showsStationLogo {
                    Image(.stationLogo).resizable().scaledToFill()
                } else {
                    ArtworkImage(url: artworkURL)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(title, font: .headline)
                if let artist {
                    MarqueeText(artist, font: .subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Captions

    private var captionScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(captions.groups) { group in
                        groupView(group)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 24)
                .padding(.top, 120)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            // Older lines fade out under the now-playing row.
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black, location: 0.34)],
                               startPoint: .top, endPoint: .bottom)
            )
            .defaultScrollAnchor(.bottom)
            .onChange(of: captions.liveLine?.text) { scrollToEnd(proxy) }
            .onChange(of: captions.lines.count) { scrollToEnd(proxy) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func groupView(_ group: CaptionGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SpeakerLabel(speaker: group.speaker)
                .padding(.bottom, 2)
            ForEach(Array(group.lines.enumerated()), id: \.element.id) { index, line in
                lineView(line,
                         isLive: line.id == captions.liveLine?.id,
                         fromEnd: group.lines.count - 1 - index)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func lineView(_ line: CaptionLine, isLive: Bool, fromEnd: Int) -> some View {
        let isLyric = if case .lyrics = line.speaker { true } else { false }
        let size = (isLyric ? lyricSize : hostSize) * scale

        return HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(line.text)
                .font(.system(size: size, weight: isLyric ? .bold : .semibold))
                .foregroundStyle(isLive ? Color.primary : Color.primary.opacity(opacity(fromEnd)))
                .fixedSize(horizontal: false, vertical: true)
            if isLive { LiveCaret(height: size * 0.95) }
        }
        .contentTransition(.opacity)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: line.text)
    }

    /// Older lines fade so the eye stays on the newest one.
    private func opacity(_ fromEnd: Int) -> Double {
        switch fromEnd {
        case 0: 0.68
        case 1: 0.5
        default: 0.38
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if captions.isRunning, captions.mode == .talk || captions.captionsMusic {
            Text("Listening…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Footnote

    private var footnote: some View {
        let (symbol, message) = status
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
            Text(message)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var status: (String, String) {
        if let message = captions.errorMessage {
            return ("exclamationmark.circle.fill", message)
        }
        if case .downloading(let fraction) = captions.availability {
            return ("arrow.down.circle.fill", "Downloading the speech model… \(Int(fraction * 100))%")
        }
        if !captions.isPlaying {
            return ("play.circle.fill", "Captions start when the radio plays.")
        }
        if !captions.isRunning || captions.mode == nil {
            return ("hourglass", "Starting captions…")
        }
        if captions.mode == .music, !captions.captionsMusic {
            return ("music.note", "Music playing. Captions resume when the talking starts.")
        }
        return ("info.circle.fill", "Live captions are made on this iPhone and may lag a few seconds.")
    }
}

/// "THE ARVO SHOW · HOST" or "LYRICS · OFFSHORE" above a group of lines.
struct SpeakerLabel: View {
    let speaker: CaptionSpeaker
    @Environment(\.accentChoice) private var accent

    var body: some View {
        switch speaker {
        case .host(let show):
            Label(show.uppercased() + " · HOST", systemImage: "mic.fill")
                .foregroundStyle(.secondary)
                .labelStyle(.compact)
        case .lyrics(let track):
            Label("LYRICS · " + track.uppercased(), systemImage: "music.note")
                .foregroundStyle(accent.color)
                .labelStyle(.compact)
        }
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.caption2.weight(.bold))
            configuration.title.font(.caption2.weight(.semibold)).kerning(0.9)
        }
        .lineLimit(1)
    }
}

private extension LabelStyle where Self == CompactLabelStyle {
    static var compact: CompactLabelStyle { .init() }
}

/// The blinking cursor after a line that's still being heard.
struct LiveCaret: View {
    var height: CGFloat
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accentChoice) private var accent

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent.color)
            .frame(width: 3, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.01).delay(0.5).repeatForever()) { visible = false }
            }
            .accessibilityHidden(true)
    }
}
