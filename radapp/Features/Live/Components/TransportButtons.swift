import SwiftUI

// the big round play / pause button
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
            // shrinks a little while paused
            .scaleEffect(isPlaying ? 1 : 0.95)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

// the heart button beside play
struct FavoriteToggleButton: View {
    let isFavorite: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var filledColor: Color {
        if colorScheme == .dark {
            return PlayerPalette.favoriteFilled
        }
        return PlayerPalette.error
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.primary)
                // fixed size so it never outgrows its 56pt box
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17))
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

// the alarm button with a menu of stop times
struct SleepTimerButton: View {
    let endsAt: Date?
    // end of the show on air, offered when known
    let showEndsAt: Date?
    let onSet: (Date?) -> Void

    private static let durations = [5, 15, 30, 45, 60]

    var body: some View {
        Menu {
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
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary)
                Group {
                    // a countdown while the timer runs
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
        .accessibilityValue(timerDescription)
    }

    // "1 hour" or "15 minutes"
    private func label(for minutes: Int) -> String {
        if minutes == 60 {
            return "1 hour"
        }
        return "\(minutes) minutes"
    }

    // what voiceover says about the timer
    private var timerDescription: String {
        guard let endsAt else {
            return "Off"
        }
        return "Stops at \(endsAt.formatted(date: .omitted, time: .shortened))"
    }
}
