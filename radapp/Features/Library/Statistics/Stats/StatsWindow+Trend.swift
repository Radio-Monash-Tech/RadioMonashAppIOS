import Foundation

extension StatsWindow {
    // more, less or the same as the previous period
    func trend(comparing total: TimeInterval, with allSegments: [ListeningSegment]) -> ListeningStats.Trend? {
        let previousTotal = previousPeriodSeconds(in: allSegments)
        if previousTotal > 0 {
            return Self.change(from: previousTotal, to: total)
        }
        // nothing last period, but maybe you started listening during this one
        if let firstListen = allSegments.map(\.start).min(), interval.contains(firstListen) {
            return .startedListening(firstListen)
        }
        return nil
    }

    // seconds listened in the whole previous week, month or year
    private func previousPeriodSeconds(in allSegments: [ListeningSegment]) -> TimeInterval {
        // one second before this period is inside the previous one
        let justBefore = interval.start.addingTimeInterval(-1)
        // guard exits early if the check fails
        guard let previous = calendar.dateInterval(of: period.component, for: justBefore) else {
            return 0
        }
        return Self.seconds(in: previous, from: allSegments)
    }

    private static func change(from previous: TimeInterval, to current: TimeInterval) -> ListeningStats.Trend {
        let difference = current - previous
        // within a minute counts as the same
        if abs(difference) < 60 {
            return .same
        }
        if difference > 0 {
            return .more(difference)
        }
        return .less(-difference)
    }
}
