import UIKit
import WidgetKit

// one moment of the widget: what the app last saved, cover included
struct RadioEntry: TimelineEntry {
    let date: Date
    let snapshot: RadioWidgetSnapshot
    let artwork: UIImage?
}

// hands ios the widget's entries
struct RadioProvider: TimelineProvider {
    func placeholder(in context: Context) -> RadioEntry {
        RadioEntry(date: .now, snapshot: .placeholder, artwork: nil)
    }

    // the gallery preview gets the placeholder
    func getSnapshot(in context: Context, completion: @escaping (RadioEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(currentEntry())
        }
    }

    // refreshes every 15 minutes so "up next" moves on while the app is closed
    func getTimeline(in context: Context, completion: @escaping (Timeline<RadioEntry>) -> Void) {
        let next = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> RadioEntry {
        let snapshot = RadioWidgetSnapshot.load() ?? .placeholder
        return RadioEntry(date: .now, snapshot: snapshot, artwork: Self.artwork(named: snapshot.artworkFileName))
    }

    // the saved cover, nil for the station logo
    private static func artwork(named name: String?) -> UIImage? {
        guard let name, let url = WidgetArtwork.fileURL(named: WidgetArtwork.largeFileName(for: name)) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
