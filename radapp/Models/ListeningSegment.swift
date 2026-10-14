import Foundation
import SwiftData

/// A stretch of time the stream played without the show changing. One
/// listening session is every segment sharing a `sessionID`, so a show
/// changing over or a dropped connection doesn't count as a new session.
@Model
final class ListeningSegment {
    var sessionID: UUID
    var start: Date
    var end: Date
    var showName: String?
    var seriesID: String?

    init(sessionID: UUID, start: Date, showName: String?, seriesID: String?) {
        self.sessionID = sessionID
        self.start = start
        end = start
        self.showName = showName
        self.seriesID = seriesID
    }

    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    /// Seconds of this segment that fall inside `interval`.
    func overlap(with interval: DateInterval) -> TimeInterval {
        max(0, min(end, interval.end).timeIntervalSince(max(start, interval.start)))
    }
}
