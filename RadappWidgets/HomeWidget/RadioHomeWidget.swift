import SwiftUI
import WidgetKit

/// Home Screen widgets: small (full-bleed cover), medium and large. The app
/// keeps a `RadioWidgetSnapshot` up to date and reloads them when it changes.
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

struct RadioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RadioEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallRadioView(entry: entry)
            case .systemMedium: MediumRadioView(entry: entry)
            default: LargeRadioView(entry: entry)
            }
        }
        .modifier(AppAppearance(isDark: entry.snapshot.isDark))
    }
}

/// Matches the app's Appearance setting rather than iOS's when it's set to
/// Light or Dark.
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
