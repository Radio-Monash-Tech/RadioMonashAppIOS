import SwiftUI
import WidgetKit

// the large widget: the medium layout, plus when the show ends and the rest of today
struct LargeRadioView: View {
    let entry: RadioEntry
    private var s: RadioWidgetSnapshot {
        entry.snapshot
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if s.isOnAir {
                StationLabel()
            }

            HStack(alignment: .top, spacing: 13) {
                Cover(image: entry.artwork, corner: 13)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    if let subtitle = s.subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        PlayButton(isPlaying: s.isPlaying)
                        LikeButton(isLiked: s.isLiked)
                    }
                }
                .frame(height: 92)
            }
            .padding(.top, s.isOnAir ? 12 : 0)

            if s.isOnAir {
                showTiming.padding(.top, 14)
            }

            Divider()
                .padding(.top, 14)
                .padding(.bottom, 10)

            Text("Up next")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            if upNext.isEmpty {
                Text("No more shows today.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            ForEach(Array(upNext.enumerated()), id: \.element) { index, show in
                // a line between shows
                if index > 0 {
                    Divider()
                }
                HStack(spacing: 12) {
                    Text(show.start, format: .dateTime.hour().minute())
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 64, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(show.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        if let hosts = show.hosts {
                            Text(hosts)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    if show.isFollowed {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AccentChoice.current.color)
                            .accessibilityLabel("Following")
                    }
                }
                .frame(height: 42)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(widgetBackground(s), for: .widget)
    }

    // MARK: - Parts

    // the next three shows that haven't started
    private var upNext: [RadioWidgetSnapshot.UpcomingShow] {
        let notStarted = s.upNext.filter { show in
            show.start > entry.date
        }
        return Array(notStarted.prefix(3))
    }

    // the show's name and "until 10:00 am"
    private var showTiming: some View {
        HStack {
            Text(s.showName ?? s.title)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let until = untilText(s) {
                Text(until)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
