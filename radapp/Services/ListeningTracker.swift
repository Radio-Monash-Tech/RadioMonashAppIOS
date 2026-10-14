import Foundation
import SwiftData

/// Records how long the stream plays, and which show was on, for Listening
/// Statistics. Everything stays in the on-device database.
@MainActor
final class ListeningTracker {
    struct Show: Equatable {
        var name: String
        var seriesID: String?
    }

    private let modelContext: ModelContext
    private var segment: ListeningSegment?
    private var sessionID: UUID?
    private var checkpointTask: Task<Void, Never>?

    /// How often an open segment is saved, so a crash or force quit loses at most this much.
    private static let checkpointInterval: Duration = .seconds(30)
    /// Shorter blips (a quick play/pause) aren't worth keeping.
    private static let minimumSegment: TimeInterval = 5

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func update(state: StreamState, show: Show?) {
        switch state {
        case .playing:
            if let segment, segment.showName == show?.name, segment.seriesID == show?.seriesID { return }
            closeSegment()
            open(show: show)
        case .connecting:
            // Reconnecting mid-listen carries on the same session.
            closeSegment()
        case .idle, .paused, .failed:
            closeSegment()
            sessionID = nil
        }
    }

    /// Deletes everything recorded. The caller calls `update` straight after
    /// so a stream that's playing starts counting again from now.
    func reset() {
        checkpointTask?.cancel()
        checkpointTask = nil
        segment = nil
        sessionID = nil
        // Deleted one by one so open @Query views notice straight away.
        for segment in (try? modelContext.fetch(FetchDescriptor<ListeningSegment>())) ?? [] {
            modelContext.delete(segment)
        }
        try? modelContext.save()
    }

    private func open(show: Show?) {
        let id = sessionID ?? UUID()
        sessionID = id
        let segment = ListeningSegment(sessionID: id, start: .now, showName: show?.name, seriesID: show?.seriesID)
        modelContext.insert(segment)
        self.segment = segment
        checkpointTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.checkpointInterval)
                guard !Task.isCancelled, let self else { return }
                self.segment?.end = .now
                try? self.modelContext.save()
            }
        }
    }

    private func closeSegment() {
        checkpointTask?.cancel()
        checkpointTask = nil
        guard let segment else { return }
        self.segment = nil
        segment.end = .now
        if segment.duration < Self.minimumSegment { modelContext.delete(segment) }
        try? modelContext.save()
    }
}
