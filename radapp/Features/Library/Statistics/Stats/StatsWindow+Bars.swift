import Foundation

// MARK: - Bars

extension StatsWindow {
    // one bar per day, or per month in the year view
    func bars(from segments: [ListeningSegment]) -> [ListeningStats.Bucket] {
        var bars: [ListeningStats.Bucket] = []
        var start = interval.start
        while start < interval.end, let next = calendar.date(byAdding: period.bucketComponent, value: 1, to: start) {
            let bar = DateInterval(start: start, end: min(next, interval.end))
            let barLabels = labels(forBarStarting: start)
            bars.append(ListeningStats.Bucket(
                id: bars.count,
                title: barLabels.title,
                axisLabel: barLabels.axisLabel,
                seconds: Self.seconds(in: bar, from: segments),
                isFuture: bar.start > now
            ))
            start = next
        }
        return bars
    }

    // "Thursday" for the pop-up and "T" under the bar
    private func labels(forBarStarting start: Date) -> (title: String, axisLabel: String) {
        switch period {
        case .week:
            let title = start.formatted(format.weekday(.wide))
            let axisLabel = String(start.formatted(format.weekday(.abbreviated)).prefix(1))
            return (title, axisLabel)
        case .month:
            let title = start.formatted(format.day().month(.wide))
            let day = calendar.component(.day, from: start)
            // only label one day a week so the numbers don't crowd
            if [1, 8, 15, 22, 29].contains(day) {
                return (title, "\(day)")
            }
            return (title, "")
        case .year:
            let title = start.formatted(format.month(.wide))
            let axisLabel = String(start.formatted(format.month(.abbreviated)).prefix(1))
            return (title, axisLabel)
        }
    }
}

// MARK: - Bar helpers

extension ListeningStats {
    // the last bar that isn't in the future
    static func todaysBar(in buckets: [Bucket]) -> Int {
        let today = buckets.lastIndex { bucket in
            !bucket.isFuture
        }
        return today ?? 0
    }

    // average from the first bar with listening up to today, so days before you installed the app don't count
    static func average(of buckets: [Bucket], upTo today: Int) -> TimeInterval? {
        // guard exits early if the check fails
        guard let first = buckets.firstIndex(where: { bucket in bucket.seconds > 0 }),
              today > first
        else {
            return nil
        }
        let counted = buckets[first...today]
        let countedTotal = counted.reduce(0) { sum, bucket in
            sum + bucket.seconds
        }
        return countedTotal / Double(counted.count)
    }
}
