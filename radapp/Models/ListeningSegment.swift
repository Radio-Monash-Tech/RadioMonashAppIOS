import Foundation
import SwiftData

// a stretch of listening during one show; segments sharing a session id are one listen
@Model
final class ListeningSegment {
    var sessionID: UUID
    var start: Date
    var end: Date
    var showName: String?
    var seriesID: String?

    // starts with no length; the tracker moves end on as you listen
    init(sessionID: UUID, start: Date, showName: String?, seriesID: String?) {
        self.sessionID = sessionID
        self.start = start
        end = start
        self.showName = showName
        self.seriesID = seriesID
    }

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    // seconds of this segment inside the interval
    func overlap(with interval: DateInterval) -> TimeInterval {
        let overlapStart = max(start, interval.start)
        let overlapEnd = min(end, interval.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}
