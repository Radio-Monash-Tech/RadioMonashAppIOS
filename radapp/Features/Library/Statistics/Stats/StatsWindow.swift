import Foundation

// the week, month or year being looked at, on the melbourne calendar
struct StatsWindow {
    let period: StatsPeriod
    // when it starts and ends
    let interval: DateInterval
    let now: Date
    let calendar: Calendar
    // dates shown in melbourne time
    let format: Date.FormatStyle

    init(period: StatsPeriod, now: Date, calendar: Calendar) {
        self.period = period
        self.now = now
        self.calendar = calendar
        interval = calendar.dateInterval(of: period.component, for: now) ?? DateInterval(start: now, duration: 0)
        format = Date.FormatStyle(timeZone: calendar.timeZone)
    }

    // only the listening that falls inside the window
    func segments(in allSegments: [ListeningSegment]) -> [ListeningSegment] {
        allSegments.filter { segment in
            segment.overlap(with: interval) > 0
        }
    }

    // only the songs liked inside the window
    func likes(in allLikes: [FavouriteTrack]) -> [FavouriteTrack] {
        allLikes.filter { like in
            interval.contains(like.savedAt)
        }
    }

    // seconds of listening inside the window
    func seconds(in segments: [ListeningSegment]) -> TimeInterval {
        Self.seconds(in: interval, from: segments)
    }

    // seconds of listening inside any interval; only the part of each segment inside it counts
    static func seconds(in interval: DateInterval, from segments: [ListeningSegment]) -> TimeInterval {
        segments.reduce(0) { sum, segment in
            sum + segment.overlap(with: interval)
        }
    }

    // "3–9 Nov", "November" or "2026"
    var label: String {
        switch period {
        case .week:
            let firstDay = interval.start
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            if calendar.isDate(firstDay, equalTo: lastDay, toGranularity: .month) {
                // same month, "3–9 Nov"
                return "\(firstDay.formatted(format.day()))–\(lastDay.formatted(format.day().month(.abbreviated)))"
            }
            // across two months, "28 Oct – 3 Nov"
            return "\(firstDay.formatted(format.day().month(.abbreviated))) – \(lastDay.formatted(format.day().month(.abbreviated)))"
        case .month:
            return interval.start.formatted(format.month(.wide))
        case .year:
            return interval.start.formatted(format.year())
        }
    }
}
