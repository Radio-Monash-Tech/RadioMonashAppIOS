import Foundation

/// Cover art handed from the app to the Live Activity. The widget can't
/// download images itself, so the app saves a small copy into the shared
/// App Group container and the activity state carries its file name.
nonisolated enum WidgetArtwork {
    static let appGroup = "group.edu.monash.radapp"

    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("LiveActivityArtwork", isDirectory: true)
    }

    static func fileURL(named name: String) -> URL? {
        directory?.appendingPathComponent(name)
    }
}
