import SwiftUI
import WidgetKit

// MARK: - Widget

// the home screen widget in small, medium and large
struct RadioHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RadioWidgetSnapshot.widgetKind, provider: RadioProvider()) { entry in
            RadioWidgetView(entry: entry)
        }
        .configurationDisplayName("Radio Monash")
        .description("What's on air now, with play and like.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Size picker

// picks the layout for the widget's size
struct RadioWidgetView: View {
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.widgetFamily) private var family
    let entry: RadioEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallRadioView(entry: entry)
            case .systemMedium:
                MediumRadioView(entry: entry)
            default:
                LargeRadioView(entry: entry)
            }
        }
        .modifier(AppAppearance(isDark: entry.snapshot.isDark))
    }
}

// MARK: - App appearance

// follows the app's light or dark setting instead of ios when one is picked
struct AppAppearance: ViewModifier {
    let isDark: Bool?

    func body(content: Content) -> some View {
        if let isDark {
            content.environment(\.colorScheme, isDark ? .dark : .light)
        } else {
            content
        }
    }
}

// MARK: - Previews

// #Preview macro, shows this view in Xcode's canvas
#Preview("Small", as: .systemSmall) {
    RadioHomeWidget()
} timeline: {
    RadioEntry(date: .now, snapshot: .placeholder, artwork: nil)
}

#Preview("Medium", as: .systemMedium) {
    RadioHomeWidget()
} timeline: {
    RadioEntry(date: .now, snapshot: .placeholder, artwork: nil)
}

#Preview("Large", as: .systemLarge) {
    RadioHomeWidget()
} timeline: {
    RadioEntry(date: .now, snapshot: .placeholder, artwork: nil)
}
