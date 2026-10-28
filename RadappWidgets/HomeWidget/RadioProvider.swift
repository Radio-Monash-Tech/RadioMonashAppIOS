import UIKit
import WidgetKit

/// Reads what the app last saved for the widget, cover included.
struct RadioEntry: TimelineEntry {
    let date: Date
    let snapshot: RadioWidgetSnapshot
    let artwork: UIImage?
}

struct RadioProvider: TimelineProvider {
    func placeholder(in context: Context) -> RadioEntry {
        RadioEntry(date: .now, snapshot: .placeholder, artwork: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RadioEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RadioEntry>) -> Void) {
        // The app reloads the widget when anything changes; this is a fallback
        // so "Up next" moves on even while the app isn't running.
        let next = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> RadioEntry {
        let snapshot = RadioWidgetSnapshot.load() ?? .placeholder
        return RadioEntry(date: .now, snapshot: snapshot, artwork: Self.artwork(named: snapshot.artworkFileName))
    }

    private static func artwork(named name: String?) -> UIImage? {
        guard let name, let url = WidgetArtwork.fileURL(named: WidgetArtwork.largeFileName(for: name)) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
