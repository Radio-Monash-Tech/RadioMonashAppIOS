import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let accent = Brand.accent

struct RadioLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadioActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(white: 0.11).opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StationArtwork(size: 52)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityControls(state: state, size: 40)
                }
                DynamicIslandExpandedRegion(.center) {
                    TrackText(state: state, compact: true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ShowProgressBar(window: state.progressWindow)
                }
            } compactLeading: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(accent)
            } compactTrailing: {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(accent)
                    .symbolEffect(.variableColor.iterative, isActive: state.isPlaying)
            } minimal: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }
}

private struct LockScreenView: View {
    let state: RadioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(accent).frame(width: 7, height: 7)
                Text(state.isPlaying ? "RADMON RADIO · LIVE" : "RADMON RADIO · PAUSED")
                    .font(.caption.weight(.bold))
                    .kerning(1.5)
                    .foregroundStyle(accent)
            }

            HStack(spacing: 14) {
                StationArtwork(size: 64)
                TrackText(state: state, compact: false)
                Spacer(minLength: 8)
                ActivityControls(state: state, size: 44)
            }

            ShowProgressBar(window: state.progressWindow)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

private struct TrackText: View {
    let state: RadioActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.title)
                .font(compact ? .headline : .title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(state.artist)
                .font(compact ? .subheadline : .body)
                .foregroundStyle(.white.opacity(0.6))
            if let billing = state.showBilling, !compact {
                Text(billing)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActivityControls: View {
    let state: RadioActivityAttributes.ContentState
    let size: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: TogglePlaybackIntent()) {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")

            Button(intent: ToggleLikeIntent()) {
                Image(systemName: state.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(state.isLiked ? PlayerPalette.favoriteFilled : .white)
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel(state.isLiked ? "Unlike" : "Like")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct StationArtwork: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2)
            .fill(Color(white: 0.2))
            .overlay {
                HStack(spacing: size * 0.08) {
                    ForEach(0..<12, id: \.self) { _ in
                        Rectangle().fill(.white.opacity(0.04)).frame(width: size * 0.08)
                    }
                }
                .frame(width: size * 2)
                .rotationEffect(.degrees(45))
            }
            .overlay {
                Text("RM")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
            .frame(width: size, height: size)
    }
}

private struct ShowProgressBar: View {
    let window: ClosedRange<Date>?

    var body: some View {
        if let window {
            ProgressView(timerInterval: window, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(accent)
        }
    }
}

#Preview("Lock Screen", as: .content, using: RadioActivityAttributes()) {
    RadioLiveActivity()
} contentStates: {
    RadioActivityAttributes.ContentState(
        title: "Wedding Riff", artist: "Mellowing", showBilling: "Afternoon Drift with Kaia",
        isPlaying: true, isLiked: false,
        progressStart: .now.addingTimeInterval(-40 * 60), progressEnd: .now.addingTimeInterval(80 * 60)
    )
}
