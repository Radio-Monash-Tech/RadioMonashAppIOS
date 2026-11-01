import SwiftUI
import WidgetKit

// the medium widget: cover on the left, title and buttons on the right
struct MediumRadioView: View {
    let entry: RadioEntry
    private var s: RadioWidgetSnapshot {
        entry.snapshot
    }

    var body: some View {
        HStack(spacing: 14) {
            Cover(image: entry.artwork, corner: 14)
                .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 0) {
                if s.isOnAir {
                    StationLabel()
                    // the title is already the show
                    Text("On air now")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 8)
                }
                Text(s.title)
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .padding(.top, 3)
                if let subtitle = s.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    PlayButton(isPlaying: s.isPlaying)
                    LikeButton(isLiked: s.isLiked)
                    Spacer(minLength: 0)
                    if let until = untilText(s) {
                        Text(until)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .containerBackground(widgetBackground(s), for: .widget)
    }
}
