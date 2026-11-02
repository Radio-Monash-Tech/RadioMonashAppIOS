import AppIntents
import SwiftUI

// pieces shared by the small, medium and large widgets

// MARK: - Background

// the background in the app's appearance, worked out up front since ios draws it outside the view
func widgetBackground(_ snapshot: RadioWidgetSnapshot) -> Color {
    // guard exits early if the check fails
    guard let isDark = snapshot.isDark else {
        return Color(.systemBackground)
    }
    let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
    return Color(uiColor: UIColor.systemBackground.resolvedColor(with: traits))
}

// MARK: - Labels

// a dot and LIVE, only while a show is on
struct LiveLabel: View {
    var onImage = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(AccentChoice.current.color).frame(width: 6, height: 6)
            Text("LIVE").foregroundStyle(onImage ? .white : AccentChoice.current.color)
        }
        .font(.system(size: 10, weight: .bold))
        .kerning(0.9)
    }
}

// "LIVE · RADIO MONASH"
struct StationLabel: View {
    var body: some View {
        HStack(spacing: 6) {
            LiveLabel()
            Text("· RADIO MONASH")
                .font(.system(size: 10, weight: .heavy))
                .kerning(0.9)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Cover

// the song's cover if the app saved one, otherwise the station logo
struct Cover: View {
    let image: UIImage?
    var corner: CGFloat = 0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image("StationLogo").resizable().scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

// runs in the app, so it can start the stream even when the app isn't open
struct PlayButton: View {
    let isPlaying: Bool

    var body: some View {
        Button(intent: TogglePlaybackIntent()) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AccentChoice.current.onColor)
                .frame(width: 40, height: 40)
                .background(AccentChoice.current.color, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

// likes the song on air
struct LikeButton: View {
    let isLiked: Bool

    var body: some View {
        Button(intent: ToggleLikeIntent()) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isLiked ? AccentChoice.current.color : .primary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Like this track")
        .accessibilityValue(isLiked ? "Liked" : "Not liked")
    }
}

// MARK: - Text helpers

// "until 10:00 am", only while a show is on
func untilText(_ snapshot: RadioWidgetSnapshot) -> String? {
    guard snapshot.isOnAir, let end = snapshot.showEnd else {
        return nil
    }
    return "until " + end.formatted(date: .omitted, time: .shortened)
}
