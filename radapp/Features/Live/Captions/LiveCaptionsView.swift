import SwiftUI

// MARK: - Live captions view

// captions in place of the artwork, newest line at the bottom
struct LiveCaptionsView: View {
    // MARK: - Inputs

    // the shared caption state
    let captions: CaptionCoordinator
    // song or show name for the top row
    let title: String
    // shown under the title, if there is one
    let artist: String?
    // cover art for the top row
    let artworkURL: URL?
    // use the station logo instead of the artwork
    let showsStationLogo: Bool

    // MARK: - State

    // the caption size set in the phone's accessibility settings
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var systemSize = CaptionStyle.systemRelativeSize
    // talk text size, grows with dynamic type
    // @ScaledMetric property wrapper, grows with the dynamic type text size
    @ScaledMetric(relativeTo: .title3) private var hostSize: CGFloat = 20
    // lyrics text size, a bit bigger
    @ScaledMetric(relativeTo: .title2) private var lyricSize: CGFloat = 25
    // skips animations when reduce motion is on
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // used to recheck the caption size when the app comes back
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Size

    // the Aa size combined with the system size
    private var scale: CGFloat {
        captions.textSize.scale(system: systemSize)
    }

    // MARK: - Body

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
        // pick up caption style changes from settings
        .onReceive(NotificationCenter.default.publisher(for: CaptionStyle.didChange)) { _ in
            systemSize = CaptionStyle.systemRelativeSize
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                systemSize = CaptionStyle.systemRelativeSize
            }
        }
    }

    // MARK: - Now playing row

    // small artwork, title and artist
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

    // MARK: - Caption list

    // the scrolling captions, kept at the bottom as lines arrive
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
            // older lines fade out under the now-playing row
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black, location: 0.34)],
                               startPoint: .top, endPoint: .bottom)
            )
            .defaultScrollAnchor(.bottom)
            .onChange(of: captions.liveLine?.text) {
                scrollToEnd(proxy)
            }
            .onChange(of: captions.lines.count) {
                scrollToEnd(proxy)
            }
        }
    }

    // scrolls to the newest line
    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("bottom", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // a speaker label and their lines
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

    // one line, lyrics are bigger and bolder, the live line has a cursor
    private func lineView(_ line: CaptionLine, isLive: Bool, fromEnd: Int) -> some View {
        let isLyric: Bool
        if case .lyrics = line.speaker {
            isLyric = true
        } else {
            isLyric = false
        }
        let size = (isLyric ? lyricSize : hostSize) * scale

        return HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(line.text)
                .font(.system(size: size, weight: isLyric ? .bold : .semibold))
                .foregroundStyle(isLive ? Color.primary : Color.primary.opacity(opacity(fromEnd)))
                .fixedSize(horizontal: false, vertical: true)
            if isLive {
                LiveCaret(height: size * 0.95)
            }
        }
        .contentTransition(.opacity)
        .animation(lineAnimation, value: line.text)
    }

    // no animation with reduce motion
    private var lineAnimation: Animation? {
        if reduceMotion {
            return nil
        }
        return .easeOut(duration: 0.2)
    }

    // older lines fade so the eye stays on the newest
    private func opacity(_ fromEnd: Int) -> Double {
        switch fromEnd {
        case 0:
            0.68
        case 1:
            0.5
        default:
            0.38
        }
    }

    // MARK: - Empty state and status

    // @ViewBuilder lets each branch return a different view
    @ViewBuilder
    private var emptyState: some View {
        if captions.isRunning, captions.mode == .talk || captions.captionsMusic {
            Text("Listening…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // the status line under the captions
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

    // icon and message for what the captions are doing
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

// MARK: - Speaker label

// "THE ARVO SHOW · HOST" or "LYRICS · SONG" above a group
struct SpeakerLabel: View {
    // who the group belongs to
    let speaker: CaptionSpeaker
    // lyrics labels use the accent colour
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

// MARK: - Compact label style

// a small icon and spaced-out text on one line
private struct CompactLabelStyle: LabelStyle {
    // lays out the icon and title
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.caption2.weight(.bold))
            configuration.title.font(.caption2.weight(.semibold)).kerning(0.9)
        }
        .lineLimit(1)
    }
}

private extension LabelStyle where Self == CompactLabelStyle {
    // lets callers write .labelStyle(.compact)
    static var compact: CompactLabelStyle {
        .init()
    }
}

// MARK: - Live caret

// the blinking cursor after the line still being heard
struct LiveCaret: View {
    // matches the line's text height
    var height: CGFloat
    // toggled to make it blink
    @State private var visible = true
    // stays still with reduce motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // the cursor's colour
    @Environment(\.accentChoice) private var accent

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(accent.color)
            .frame(width: 3, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                // stays still with reduce motion
                // guard exits early if the check fails
                guard !reduceMotion else {
                    return
                }
                withAnimation(.linear(duration: 0.01).delay(0.5).repeatForever()) {
                    visible = false
                }
            }
            .accessibilityHidden(true)
    }
}
