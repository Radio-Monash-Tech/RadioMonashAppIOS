import Foundation
import Combine

// this week's schedule, with an offline copy
// @MainActor runs this on the main thread
@MainActor
final class ScheduleStore: ObservableObject {
    // MARK: - State the screen reads

    enum Phase: Equatable {
        case idle, loading, loaded, failed(String)
    }

    // @Published property wrapper, views watching this object redraw when it changes
    @Published private(set) var shows: [ScheduledShow] = []
    @Published private(set) var phase: Phase = .idle
    // set only while showing the saved copy because loading failed
    @Published private(set) var offlineCopyDate: Date?

    // MARK: - Private state

    private let client = RadioCultClient.shared
    private var loadedAt: Date?
    private var cachedAt: Date?
    // reload after 15 minutes
    private let staleAfter: TimeInterval = 15 * 60
    private static let cacheName = "schedule"

    // MARK: - Init

    // init sets up a new instance
    init() {
        // show the last schedule straight away; the first load replaces it
        if let cached = OfflineCache.load([ScheduledShow].self, named: Self.cacheName) {
            shows = cached.value
            cachedAt = cached.savedAt
        }
    }

    // MARK: - Lookups

    // the seven days of this melbourne week, monday first
    var week: [Date] {
        let calendar = Calendar.melbourne
        // guard exits early if the check fails
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    // each show once, in schedule order
    var series: [ShowSeries] {
        var seen = Set<String>()
        return shows.compactMap { show in
            guard seen.insert(show.series.id).inserted else {
                return nil
            }
            return show.series
        }
    }

    func shows(on day: Date) -> [ScheduledShow] {
        shows.filter { show in
            Calendar.melbourne.isDate(show.start, inSameDayAs: day)
        }
    }

    // every episode of one show this week
    func occurrences(of seriesID: String) -> [ScheduledShow] {
        shows.filter { show in
            show.series.id == seriesID
        }
    }

    // the next episode that hasn't finished
    func nextOccurrence(of seriesID: String, after date: Date = .now) -> ScheduledShow? {
        occurrences(of: seriesID).first { show in
            show.end > date
        }
    }

    func onAir(at date: Date = .now) -> ScheduledShow? {
        shows.first { show in
            show.isOnAir(at: date)
        }
    }

    // MARK: - Loading

    // loads unless it was loaded in the last 15 minutes
    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < staleAfter {
            return
        }
        guard phase != .loading else {
            return
        }
        await load()
    }

    func load() async {
        guard let interval = Calendar.melbourne.dateInterval(of: .weekOfYear, for: .now) else {
            return
        }
        phase = .loading
        do {
            shows = try await client.schedule(from: interval.start, to: interval.end)
            loadedAt = .now
            cachedAt = .now
            offlineCopyDate = nil
            phase = .loaded
            OfflineCache.save(shows, as: Self.cacheName)
        } catch is CancellationError {
            finishCancelled()
        } catch let error as URLError where error.code == .cancelled {
            finishCancelled()
        } catch {
            if !shows.isEmpty {
                // keep showing the saved copy rather than an error
                offlineCopyDate = cachedAt
                phase = .loaded
            } else if (error as? URLError)?.code == .notConnectedToInternet {
                phase = .failed("You're offline. Connect to the internet to see this week's shows.")
            } else {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't load the schedule.")
            }
        }
    }

    // a cancelled load isn't an error
    private func finishCancelled() {
        if shows.isEmpty {
            phase = .idle
        } else {
            phase = .loaded
        }
    }
}
