import Foundation
import Combine

@MainActor
final class ScheduleStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed(String)
    }

    @Published private(set) var shows: [ScheduledShow] = []
    @Published private(set) var phase: Phase = .idle
    /// When the shown schedule was downloaded, set only while the latest
    /// download failed and the saved copy is on screen instead.
    @Published private(set) var offlineCopyDate: Date?

    private let client = RadioCultClient.shared
    private var loadedAt: Date?
    private var cachedAt: Date?
    private let staleAfter: TimeInterval = 15 * 60
    private static let cacheName = "schedule"

    init() {
        // Show the last schedule straight away; the first load replaces it.
        if let cached = OfflineCache.load([ScheduledShow].self, named: Self.cacheName) {
            shows = cached.value
            cachedAt = cached.savedAt
        }
    }

    var week: [Date] {
        let calendar = Calendar.melbourne
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var series: [ShowSeries] {
        var seen = Set<String>()
        return shows.compactMap { seen.insert($0.series.id).inserted ? $0.series : nil }
    }

    func shows(on day: Date) -> [ScheduledShow] {
        shows.filter { Calendar.melbourne.isDate($0.start, inSameDayAs: day) }
    }

    func occurrences(of seriesID: String) -> [ScheduledShow] {
        shows.filter { $0.series.id == seriesID }
    }

    func nextOccurrence(of seriesID: String, after date: Date = .now) -> ScheduledShow? {
        occurrences(of: seriesID).first { $0.end > date }
    }

    func onAir(at date: Date = .now) -> ScheduledShow? {
        shows.first { $0.isOnAir(at: date) }
    }

    func loadIfNeeded() async {
        if let loadedAt, Date().timeIntervalSince(loadedAt) < staleAfter { return }
        guard phase != .loading else { return }
        await load()
    }

    func load() async {
        guard let interval = Calendar.melbourne.dateInterval(of: .weekOfYear, for: .now) else { return }
        phase = .loading
        do {
            shows = try await client.schedule(from: interval.start, to: interval.end)
            loadedAt = .now
            cachedAt = .now
            offlineCopyDate = nil
            phase = .loaded
            OfflineCache.save(shows, as: Self.cacheName)
        } catch is CancellationError {
            phase = shows.isEmpty ? .idle : .loaded
        } catch let error as URLError where error.code == .cancelled {
            phase = shows.isEmpty ? .idle : .loaded
        } catch {
            if !shows.isEmpty {
                // Keep showing the saved copy rather than an error.
                offlineCopyDate = cachedAt
                phase = .loaded
            } else if (error as? URLError)?.code == .notConnectedToInternet {
                phase = .failed("You're offline. Connect to the internet to see this week's shows.")
            } else {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? "Couldn't load the schedule.")
            }
        }
    }
}
