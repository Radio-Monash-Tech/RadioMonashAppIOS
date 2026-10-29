import Foundation

/// Cover art handed from the app to the Home Screen widget. The widget can't
/// download images itself, so the app saves a copy into the shared App Group
/// container and the widget snapshot carries its file name.
nonisolated enum WidgetArtwork {
    static let appGroup = "group.edu.monash.radapp"

    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            // Named for the Live Activity it was first made for; kept so
            // covers already saved on phones are still found.
            .appendingPathComponent("LiveActivityArtwork", isDirectory: true)
    }

    static func fileURL(named name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }

    /// The saved cover's file. (Covers were once also saved smaller for a
    /// Live Activity, so the widget's copy has its own name.)
    static func largeFileName(for name: String) -> String {
        name.replacingOccurrences(of: ".jpg", with: "-large.jpg")
    }
}
