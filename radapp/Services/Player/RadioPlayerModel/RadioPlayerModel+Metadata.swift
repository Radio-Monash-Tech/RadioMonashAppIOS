import Combine
import UIKit

// asking radiocult for the song, show and recently played
extension RadioPlayerModel {
    // MARK: - Poll timing

    private static let soonestPoll: TimeInterval = 5
    // live shows and songs with no length give no hint when they'll change
    private static let unknownEndPoll: TimeInterval = 15
    private static let latestPoll: TimeInterval = 60
    // radiocult takes a moment to report the next song
    private static let reportingDelay: TimeInterval = 3
    private static let overdueLimit: TimeInterval = 30

    // MARK: - Polling

    func startMetadataPolling() {
        restartPolling()
        // catch up as soon as the app comes back from the background
        foregroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.restartPolling()
            }
    }

    // fetch now, then wait until the song or show should change
    func restartPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // guard exits early if the check fails
                guard let self else {
                    return
                }
                await self.refreshMetadata()
                let delay = self.nextPollDelay
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    // seconds until the next fetch
    private var nextPollDelay: TimeInterval {
        // nobody's listening, so only an occasional refresh
        guard isActive else {
            return Self.latestPoll
        }
        // retry a failed fetch sooner
        guard connectivity == .good else {
            return Self.unknownEndPoll
        }

        // when the song should finish, if known
        var trackEnd: Date?
        if let start = nowPlaying.startedAt, let duration = nowPlaying.duration {
            trackEnd = start + duration
        }

        // without a song end, the next song could start any time
        let longest: TimeInterval
        if trackEnd == nil {
            longest = Self.unknownEndPoll
        } else {
            longest = Self.latestPoll
        }

        let changes = [trackEnd, currentShowEndsAt].compactMap { date in
            date
        }
        guard let next = changes.min() else {
            return longest
        }
        let untilChange = next.timeIntervalSince(Date())

        // overdue: check again soon, then less often if it stays overdue
        if untilChange + Self.reportingDelay < Self.soonestPoll {
            if untilChange > -Self.overdueLimit {
                return Self.soonestPoll
            }
            return Self.unknownEndPoll
        }
        return min(untilChange + Self.reportingDelay, longest)
    }

    // MARK: - Fetching

    func refreshMetadata() async {
        do {
            let status = try await client.liveStatus()
            apply(status.toNowPlaying())
            setIfChanged(\.connectivity, .good)
        } catch {
            let isOffline = (error as? URLError)?.code == .notConnectedToInternet
            if isOffline {
                setIfChanged(\.connectivity, .offline)
            } else {
                setIfChanged(\.connectivity, .weak)
            }
        }

        do {
            trackHistory.reported = try await client.history(limit: TrackHistory.limit).toPlayedTracks()
        } catch {
            // keep the history we have rather than flash it empty
        }
        setIfChanged(\.history, trackHistory.recent(excluding: nowPlaying))
    }

    // stores the new song and show, and updates likes and artwork if they changed
    private func apply(_ payload: (track: NowPlaying, show: LiveShow?)) {
        let changed = payload.track != nowPlaying || payload.show != liveShow
        if payload.track != nowPlaying {
            trackHistory.recordFinished(nowPlaying)
        }
        setIfChanged(\.nowPlaying, payload.track)
        setIfChanged(\.liveShow, payload.show)
        guard changed else {
            return
        }
        refreshLikeState()
        systemPlayers.setArtwork(showsStationLogo ? nil : nowPlaying.artworkURL)
    }

    // MARK: - Helpers

    // only sets the property if the value is different, so screens don't redraw for nothing
    func setIfChanged<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<RadioPlayerModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
