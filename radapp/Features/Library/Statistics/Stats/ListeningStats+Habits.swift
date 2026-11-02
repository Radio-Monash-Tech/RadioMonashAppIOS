import Foundation

// MARK: - Sessions

extension ListeningStats {
    // segments sharing a session id are one listen
    static func sessionCount(in segments: [ListeningSegment]) -> Int {
        Set(segments.map(\.sessionID)).count
    }

    static func averageSession(total: TimeInterval, sessions: Int) -> TimeInterval {
        if sessions == 0 {
            return 0
        }
        return total / Double(sessions)
    }
}

// MARK: - Streaks

extension StatsWindow {
    // longest run of days in a row with any listening
    func longestStreak(in segments: [ListeningSegment]) -> Int {
        longestRun(of: daysListened(in: segments))
    }

    // midnight of every day with any listening
    private func daysListened(in segments: [ListeningSegment]) -> Set<Date> {
        var days = Set<Date>()
        for segment in segments {
            var day = calendar.startOfDay(for: max(segment.start, interval.start))
            let end = min(segment.end, interval.end)
            // a segment past midnight counts for both days
            while day < end {
                days.insert(day)
                // guard exits early if the check fails
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                    break
                }
                day = next
            }
        }
        return days
    }

    // the most days in a row in the set
    private func longestRun(of days: Set<Date>) -> Int {
        var longest = 0
        var run = 0
        var previousDay: Date?
        for day in days.sorted() {
            if let previousDay, calendar.date(byAdding: .day, value: 1, to: previousDay) == day {
                // the day after the last one, the run carries on
                run += 1
            } else {
                // a gap, start counting again
                run = 1
            }
            longest = max(longest, run)
            previousDay = day
        }
        return longest
    }
}
