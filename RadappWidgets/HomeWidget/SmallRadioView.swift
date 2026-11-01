import SwiftUI
import WidgetKit

// the small widget: the cover fills it, with the title over a dark fade
struct SmallRadioView: View {
    let entry: RadioEntry
    private var s: RadioWidgetSnapshot {
        entry.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                PlayButton(isPlaying: s.isPlaying)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            Spacer(minLength: 0)
            if s.isOnAir {
                LiveLabel(onImage: true)
            }
            Text(s.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.top, 5)
            if let subtitle = s.subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .containerBackground(for: .widget) {
            ZStack(alignment: .bottom) {
                Cover(image: entry.artwork)
                // keeps white text readable on any cover
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black.opacity(0.45), location: 0.45),
                        .init(color: .black.opacity(0.78), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
                // the bottom 62% of the widget
                .containerRelativeFrame(.vertical) { height, _ in
                    height * 0.62
                }
            }
        }
        // the text always sits on the cover
        .environment(\.colorScheme, .dark)
    }
}
