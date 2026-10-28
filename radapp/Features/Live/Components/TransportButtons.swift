import SwiftUI

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
                // Fixed like the other transport icons, so it never outgrows its 56pt box.
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
