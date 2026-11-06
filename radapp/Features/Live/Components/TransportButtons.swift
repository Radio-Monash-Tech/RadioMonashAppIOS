import SwiftUI

// MARK: - Play button

// the big round play / pause button
struct PlaybackFAB: View {
    let isPlaying: Bool
    let action: () -> Void

    // MARK: - Sizes

    // @ScaledMetric property wrapper, grows with the dynamic type text size
    // the icon and circle grow together, so the icon never spills out
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title) private var diameter: CGFloat = 72

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.primary)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color(.systemBackground))
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            // shrinks a little while paused
            .scaleEffect(isPlaying ? 1 : 0.95)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

// MARK: - Square control

// the rounded square behind the like and sleep timer buttons
private struct SquareControl<Content: View>: View {
    // @ViewBuilder lets the caller pass in any view
    @ViewBuilder let content: Content

    // grows with text size, like the play button
    @ScaledMetric private var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.primary)
            content
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

// MARK: - Like button

// the heart button beside play
struct FavoriteToggleButton: View {
    let isFavorite: Bool
    let action: () -> Void

    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric private var iconSize: CGFloat = 17

    // red in light mode, a softer pink in dark mode
    private var filledColor: Color {
        if colorScheme == .dark {
            return PlayerPalette.favoriteFilled
        }
        return PlayerPalette.error
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            SquareControl {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: iconSize))
                    .foregroundStyle(isFavorite ? filledColor : Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .accessibilityLabel("Like this track")
        .accessibilityValue(isFavorite ? "Liked" : "Not liked")
    }
}

// MARK: - Sleep timer button

// the alarm button with a menu of stop times
struct SleepTimerButton: View {
    let endsAt: Date?
    // end of the show on air, offered when known
    let showEndsAt: Date?
    let onSet: (Date?) -> Void

    private static let durations = [5, 15, 30, 45, 60]

    // MARK: - Sizes

    // just the alarm, while the timer is off
    @ScaledMetric private var iconSize: CGFloat = 20
    // a smaller alarm with the time left underneath, while it's running
    @ScaledMetric private var countdownIconSize: CGFloat = 15
    @ScaledMetric private var countdownTextSize: CGFloat = 11

    // MARK: - Body

    var body: some View {
        Menu {
            menuItems
        } label: {
            SquareControl {
                buttonFace
                    .foregroundStyle(Color(.systemBackground))
            }
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .sensoryFeedback(.selection, trigger: endsAt)
        .accessibilityLabel("Sleep timer")
        .accessibilityValue(timerDescription)
    }

    // MARK: - Menu

    // turn off, end of show, then the set durations
    // @ViewBuilder lets each branch return a different view
    @ViewBuilder
    private var menuItems: some View {
        if endsAt != nil {
            Button("Turn Off Timer", systemImage: "xmark", role: .destructive) {
                onSet(nil)
            }
        }
        if let showEndsAt, showEndsAt > .now {
            Button("End of Show", systemImage: "calendar") {
                onSet(showEndsAt)
            }
        }
        ForEach(Self.durations, id: \.self) { minutes in
            Button(label(for: minutes)) {
                onSet(.now.addingTimeInterval(TimeInterval(minutes * 60)))
            }
        }
    }

    // MARK: - Button face

    // a countdown while the timer runs, otherwise just the alarm
    @ViewBuilder
    private var buttonFace: some View {
        if let endsAt, endsAt > .now {
            countdown(until: endsAt)
        } else {
            Image(systemName: "alarm.fill")
                .font(.system(size: iconSize))
        }
    }

    private func countdown(until endsAt: Date) -> some View {
        VStack(spacing: 1) {
            Image(systemName: "alarm.fill")
                .font(.system(size: countdownIconSize))
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(.system(size: countdownTextSize, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                // long times like 1:00:00 shrink to fit the box
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Text

    // "1 hour" or "15 minutes"
    private func label(for minutes: Int) -> String {
        if minutes == 60 {
            return "1 hour"
        }
        return "\(minutes) minutes"
    }

    // what voiceover says about the timer
    private var timerDescription: String {
        // guard exits early if the check fails
        guard let endsAt else {
            return "Off"
        }
        return "Stops at \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
}
