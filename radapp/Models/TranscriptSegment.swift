import Foundation
import SwiftData

/// One stretch of the caption transcript: a paragraph of talk, or the track
/// that played in between. Only the text is kept, never any audio.
@Model
final class TranscriptSegment {
    var startedAt: Date
    var text: String
    /// `CaptionMode` raw value: "talk" or "music".
    var kindRaw: String
    var showName: String?
    /// Groups the segments from one listening session.
    var sessionID: UUID

    init(startedAt: Date = .now, text: String, kind: CaptionMode, showName: String?, sessionID: UUID) {
        self.startedAt = startedAt
        self.text = text
        kindRaw = kind.rawValue
        self.showName = showName
        self.sessionID = sessionID
    }

    var kind: CaptionMode { CaptionMode(rawValue: kindRaw) ?? .talk }
}
