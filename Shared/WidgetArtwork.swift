import Foundation

// where the app saves cover art for the widget, which can't download images itself
// nonisolated means not tied to the main thread
nonisolated enum WidgetArtwork {
    static let appGroup = "group.edu.monash.radapp"

    // named for an old live activity; kept so covers already on phones are still found
    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("LiveActivityArtwork", isDirectory: true)
    }

    static func fileURL(named name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }

    // the widget's copy has its own name, left over from the live activity
    static func largeFileName(for name: String) -> String {
        name.replacingOccurrences(of: ".jpg", with: "-large.jpg")
    }
}
