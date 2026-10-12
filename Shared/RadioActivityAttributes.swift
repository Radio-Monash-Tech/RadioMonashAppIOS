import ActivityKit
import Foundation

/// Shared between the app (which starts and updates the activity) and the
/// widget extension (which renders it on the Lock Screen and Dynamic Island).
nonisolated struct RadioActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var artist: String
        var isPlaying: Bool
        var isLiked: Bool
        /// Window the progress bar fills across: the current track.
        var progressStart: Date?
        var progressEnd: Date?
        /// Track cover saved in `WidgetArtwork.directory`. `nil` shows the station logo.
        var artworkFileName: String? = nil

        var progressWindow: ClosedRange<Date>? {
            guard let progressStart, let progressEnd, progressStart < progressEnd else { return nil }
            return progressStart...progressEnd
        }
    }
}
