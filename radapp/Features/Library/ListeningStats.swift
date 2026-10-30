import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, year

    var id: Self { self }

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    fileprivate var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    fileprivate var bucketComponent: Calendar.Component {
        self == .year ? .month : .day
    }
}

/// Everything Listening Statistics shows for one period, worked out from the
/// recorded segments. Times are bucketed on the Melbourne calendar like the schedule.
struct ListeningStats {
    struct Bucket: Identifiable {
        let id: Int
        let title: String
        let axisLabel: String
        let seconds: TimeInterval
        let isFuture: Bool
    }

    struct ShowTotal: Identifiable {
        let id: String
        let name: String
        let seriesID: String?
        let seconds: TimeInterval
    }

    struct ArtistLikes: Identifiable {
        var id: String { name }
        let name: String
        let count: Int
    }

    enum Trend {
        case more(TimeInterval), less(TimeInterval), same
        case startedListening(Date)
    }

    let period: StatsPeriod
    let periodLabel: String
    let total: TimeInterval
    let trend: Trend?
    let buckets: [Bucket]
    let currentBucket: Int
    let average: TimeInterval?
    let sessions: Int
    let averageSession: TimeInterval
    let longestStreak: Int
    let songsLiked: Int
    let topShows: [ShowTotal]
    let topArtists: [ArtistLikes]

    init(period: StatsPeriod, segments allSegments: [ListeningSegment], likes: [FavouriteTrack],
         now: Date = .now, calendar: Calendar = .melbourne) {
        let interval = calendar.dateInterval(of: period.component, for: now) ?? DateInterval(start: now, duration: 0)
        let segments = allSegments.filter { $0.overlap(with: interval) > 0 }
        let format = Date.FormatStyle(timeZone: calendar.timeZone)
        self.period = period

        switch period {
        case .week:
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            periodLabel = calendar.isDate(interval.start, equalTo: lastDay, toGranularity: .month)
                ? "\(interval.start.formatted(format.day()))–\(lastDay.formatted(format.day().month(.abbreviated)))"
                : "\(interval.start.formatted(format.day().month(.abbreviated))) – \(lastDay.formatted(format.day().month(.abbreviated)))"
        case .month:
            periodLabel = interval.start.formatted(format.month(.wide))
        case .year:
            periodLabel = interval.start.formatted(format.year())
        }

        total = segments.reduce(0) { $0 + $1.overlap(with: interval) }

        // Bars
        var buckets: [Bucket] = []
        var start = interval.start
        while start < interval.end, let end = calendar.date(byAdding: period.bucketComponent, value: 1, to: start) {
            let bucket = DateInterval(start: start, end: min(end, interval.end))
            let index = buckets.count
            let title: String
            let axisLabel: String
            switch period {
            case .week:
                title = start.formatted(format.weekday(.wide))
                axisLabel = String(start.formatted(format.weekday(.abbreviated)).prefix(1))
            case .month:
                let day = calendar.component(.day, from: start)
                title = start.formatted(format.day().month(.wide))
                axisLabel = [1, 8, 15, 22, 29].contains(day) ? "\(day)" : ""
            case .year:
                title = start.formatted(format.month(.wide))
                axisLabel = String(start.formatted(format.month(.abbreviated)).prefix(1))
            }
            buckets.append(Bucket(
                id: index,
                title: title,
                axisLabel: axisLabel,
                seconds: segments.reduce(0) { $0 + $1.overlap(with: bucket) },
                isFuture: bucket.start > now
            ))
            start = end
        }
        self.buckets = buckets
        currentBucket = buckets.lastIndex { !$0.isFuture } ?? 0

        // The average runs from the first bucket listened in up to now, so
        // months before you installed the app don't drag it down.
        if let first = buckets.firstIndex(where: { $0.seconds > 0 }), currentBucket > first {
            let counted = buckets[first...currentBucket]
            average = counted.reduce(0) { $0 + $1.seconds } / Double(counted.count)
        } else {
            average = nil
        }

        // Trend against the whole previous period
        let previous = calendar.dateInterval(of: period.component, for: interval.start.addingTimeInterval(-1))
        let previousTotal = previous.map { previous in allSegments.reduce(0) { $0 + $1.overlap(with: previous) } } ?? 0
        let firstListen = allSegments.map(\.start).min()
        if previousTotal > 0 {
            let difference = total - previousTotal
            trend = abs(difference) < 60 ? .same : difference > 0 ? .more(difference) : .less(-difference)
        } else if let firstListen, interval.contains(firstListen) {
            trend = .startedListening(firstListen)
        } else {
            trend = nil
        }

        // Sessions
        let sessionIDs = Set(segments.map(\.sessionID))
        sessions = sessionIDs.count
        averageSession = sessionIDs.isEmpty ? 0 : total / Double(sessionIDs.count)

        // Longest run of days with any listening
        var days = Set<Date>()
        for segment in segments {
            var day = calendar.startOfDay(for: max(segment.start, interval.start))
            let end = min(segment.end, interval.end)
            while day < end {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        var longest = 0
        var run = 0
        var previousDay: Date?
        for day in days.sorted() {
            if let previousDay, calendar.date(byAdding: .day, value: 1, to: previousDay) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previousDay = day
        }
        longestStreak = longest

        // Top shows, grouped by schedule ID when known, otherwise by name
        var shows: [String: ShowTotal] = [:]
        for segment in segments {
            guard let name = segment.showName else { continue }
            let key = segment.seriesID ?? name.lowercased()
            let seconds = (shows[key]?.seconds ?? 0) + segment.overlap(with: interval)
            shows[key] = ShowTotal(id: key, name: name, seriesID: segment.seriesID ?? shows[key]?.seriesID, seconds: seconds)
        }
        topShows = Array(shows.values.sorted { $0.seconds > $1.seconds }.prefix(4))

        // Likes
        let periodLikes = likes.filter { interval.contains($0.savedAt) }
        songsLiked = periodLikes.count
        var artists: [String: ArtistLikes] = [:]
        for like in periodLikes where !like.artist.isEmpty {
            let key = like.artist.lowercased()
            artists[key] = ArtistLikes(name: artists[key]?.name ?? like.artist, count: (artists[key]?.count ?? 0) + 1)
        }
        topArtists = Array(artists.values.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.name.localizedCompare($1.name) == .orderedAscending
        }.prefix(3))
    }
}

enum ListeningDuration {
    /// "27m", "6h 00m", "32h 14m"
    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}
