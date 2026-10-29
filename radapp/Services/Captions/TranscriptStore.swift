import Foundation
import SwiftData

/// Writes finished captions into the transcript. Talk is grouped into
/// paragraphs of up to a minute and a half so the transcript reads well,
/// and anything older than two weeks is cleared to keep it small.
@MainActor
final class TranscriptStore {
    private let context: ModelContext
    private var sessionID = UUID()
    private var openTalk: TranscriptSegment?
    private var lastMusic: String?

    private static let paragraphLength: TimeInterval = 90
    private static let keepFor: TimeInterval = 14 * 24 * 60 * 60

    init(context: ModelContext) {
        self.context = context
        prune()
    }

    func beginSession() {
        sessionID = UUID()
        openTalk = nil
        lastMusic = nil
    }

    func appendTalk(_ text: String, showName: String?) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let openTalk, Date.now.timeIntervalSince(openTalk.startedAt) < Self.paragraphLength {
            openTalk.text += " " + text
        } else {
            let segment = TranscriptSegment(text: text, kind: .talk, showName: showName, sessionID: sessionID)
            context.insert(segment)
            openTalk = segment
        }
        lastMusic = nil
        try? context.save()
    }

    /// Notes the track playing between talk, once per track.
    func appendMusic(_ description: String, showName: String?) {
        openTalk = nil
        guard description != lastMusic else { return }
        lastMusic = description
        context.insert(TranscriptSegment(text: description, kind: .music, showName: showName, sessionID: sessionID))
        try? context.save()
    }

    func endTalk() {
        openTalk = nil
    }

    private func prune() {
        let cutoff = Date.now.addingTimeInterval(-Self.keepFor)
        try? context.delete(model: TranscriptSegment.self, where: #Predicate { $0.startedAt < cutoff })
        try? context.save()
    }
}
