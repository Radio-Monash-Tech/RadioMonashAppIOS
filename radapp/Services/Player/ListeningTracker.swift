import Foundation
import SwiftData

// records how long the stream plays and which show was on, on the device only
// @MainActor runs this on the main thread
@MainActor
final class ListeningTracker {
    // MARK: - State

    struct Show: Equatable {
        var name: String
        var seriesID: String?
    }

    private let modelContext: ModelContext
    // the stretch being recorded right now
    private var segment: ListeningSegment?
    private var sessionID: UUID?
    private var checkpointTask: Task<Void, Never>?

    // saved this often, so a crash loses at most 30 seconds
    private static let checkpointInterval: Duration = .seconds(30)
    // quick play/pause blips aren't kept
    private static let minimumSegment: TimeInterval = 5

    // MARK: - Recording

    // init sets up a new instance
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func update(state: StreamState, show: Show?) {
        switch state {
        case .playing:
            // same show as the open segment, so keep going
            if let segment, segment.showName == show?.name, segment.seriesID == show?.seriesID {
                return
            }
            closeSegment()
            open(show: show)
        case .connecting:
            // reconnecting carries on the same session
            closeSegment()
        case .idle, .paused, .failed:
            closeSegment()
            sessionID = nil
        }
    }

    // deletes everything; the caller calls update straight after to start counting again
    func reset() {
        checkpointTask?.cancel()
        checkpointTask = nil
        segment = nil
        sessionID = nil
        // one by one, so open @Query screens notice straight away
        let allSegments = (try? modelContext.fetch(FetchDescriptor<ListeningSegment>())) ?? []
        for segment in allSegments {
            modelContext.delete(segment)
        }
        try? modelContext.save()
    }

    // MARK: - Segments

    // starts a new segment and saves it every 30 seconds
    private func open(show: Show?) {
        let id = sessionID ?? UUID()
        sessionID = id
        let segment = ListeningSegment(sessionID: id, start: .now, showName: show?.name, seriesID: show?.seriesID)
        modelContext.insert(segment)
        self.segment = segment
        checkpointTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.checkpointInterval)
                // guard exits early if the check fails
                guard !Task.isCancelled, let self else {
                    return
                }
                self.segment?.end = .now
                try? self.modelContext.save()
            }
        }
    }

    // ends the open segment, dropping it if it was too short
    private func closeSegment() {
        checkpointTask?.cancel()
        checkpointTask = nil
        guard let segment else {
            return
        }
        self.segment = nil
        segment.end = .now
        if segment.duration < Self.minimumSegment {
            modelContext.delete(segment)
        }
        try? modelContext.save()
    }
}
