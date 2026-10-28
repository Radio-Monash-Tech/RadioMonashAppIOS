import Combine
import UIKit

// Polling RadioCult for the song, show and recently played.
extension RadioPlayerModel {
    private static let soonestPoll: TimeInterval = 5
    /// Live shows and tracks without a duration give no hint when they'll change.
    private static let unknownEndPoll: TimeInterval = 15
    private static let latestPoll: TimeInterval = 60
    /// RadioCult takes a moment to report the next track once one ends.
    private static let reportingDelay: TimeInterval = 3
    private static let overdueLimit: TimeInterval = 30

    func startMetadataPolling() {
        restartPolling()
        // iOS suspends the app in the background when nothing is playing, so
        // catch up as soon as it's back rather than waiting for the next poll.
        foregroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.restartPolling() }
    }

    /// Fetches now, then waits until the track or show should change before
    /// fetching again, so the screen updates on time without polling constantly.
    func restartPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshMetadata()
                let delay = self.nextPollDelay
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private var nextPollDelay: TimeInterval {
        // Nobody's listening, so the screen only needs an occasional refresh.
        guard isActive else { return Self.latestPoll }
        // Retry a failed fetch sooner than the next change would be due.
        guard connectivity == .good else { return Self.unknownEndPoll }

        let now = Date()
        let trackEnd = nowPlaying.startedAt.flatMap { start in nowPlaying.duration.map { start + $0 } }
        // Without a track end, the next song could start any time.
        let longest = trackEnd == nil ? Self.unknownEndPoll : Self.latestPoll
        let changes = [trackEnd, currentShowEndsAt].compactMap { $0 }
        guard let next = changes.min() else { return longest }
        let untilChange = next.timeIntervalSince(now)
        // A change that's overdue (the track overran, or RadioCult is late) is
        // checked again soon, then less often if it stays overdue.
        if untilChange + Self.reportingDelay < Self.soonestPoll {
            return untilChange > -Self.overdueLimit ? Self.soonestPoll : Self.unknownEndPoll
        }
        return min(untilChange + Self.reportingDelay, longest)
    }

    func refreshMetadata() async {
        do {
            apply(try await client.liveStatus().toNowPlaying())
            setIfChanged(\.connectivity, .good)
        } catch {
            setIfChanged(\.connectivity, (error as? URLError)?.code == .notConnectedToInternet ? .offline : .weak)
        }

        do {
            trackHistory.reported = try await client.history(limit: TrackHistory.limit).toPlayedTracks()
        } catch {
            // Keep whatever history we already have rather than flashing it empty.
        }
        setIfChanged(\.history, trackHistory.recent(excluding: nowPlaying))
    }

    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        let changed = payload.track != nowPlaying || payload.show != liveShow
        if payload.track != nowPlaying { trackHistory.recordFinished(nowPlaying) }
        setIfChanged(\.nowPlaying, payload.track)
        setIfChanged(\.liveShow, payload.show)
        guard changed else { return }
        refreshLikeState()
        systemPlayers.setArtwork(showsStationLogo ? nil : nowPlaying.artworkURL)
    }

    func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RadioPlayerModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
