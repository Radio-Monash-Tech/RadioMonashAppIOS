import Foundation

extension ListeningStats {
    // one bar in the chart
    struct Bucket: Identifiable {
        let id: Int
        // "Thursday", shown when selected
        let title: String
        // "T", shown under the bar
        let axisLabel: String
        let seconds: TimeInterval
        let isFuture: Bool
    }

    // one row in top shows
    struct ShowTotal: Identifiable {
        let id: String
        let name: String
        let seriesID: String?
        let seconds: TimeInterval
    }

    // one row in most-liked artists
    struct ArtistLikes: Identifiable {
        var id: String {
            name
        }
        let name: String
        let count: Int
    }

    // compared with the previous period
    enum Trend {
        case more(TimeInterval), less(TimeInterval), same
        // first listened during this period, so there's nothing to compare
        case startedListening(Date)
    }
}
