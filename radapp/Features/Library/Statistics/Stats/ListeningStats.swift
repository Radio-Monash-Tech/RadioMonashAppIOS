import Foundation

// all the numbers the statistics screen shows for one period
struct ListeningStats {
    let period: StatsPeriod
    // "3–9 Nov", "November" or "2026"
    let periodLabel: String
    let total: TimeInterval
    let trend: Trend?
    // the chart bars
    let buckets: [Bucket]
    // today's bar, selected by default
    let currentBucket: Int
    let average: TimeInterval?
    let sessions: Int
    let averageSession: TimeInterval
    let longestStreak: Int
    let songsLiked: Int
    let topShows: [ShowTotal]
    let topArtists: [ArtistLikes]

    init(period: StatsPeriod, segments allSegments: [ListeningSegment], likes allLikes: [FavouriteTrack],
         now: Date = .now, calendar: Calendar = .melbourne) {
        let window = StatsWindow(period: period, now: now, calendar: calendar)
        let segments = window.segments(in: allSegments)
        let likes = window.likes(in: allLikes)

        // the period
        self.period = period
        periodLabel = window.label

        // time
        total = window.seconds(in: segments)
        trend = window.trend(comparing: total, with: allSegments)

        // the chart
        buckets = window.bars(from: segments)
        currentBucket = Self.todaysBar(in: buckets)
        average = Self.average(of: buckets, upTo: currentBucket)

        // habits
        sessions = Self.sessionCount(in: segments)
        averageSession = Self.averageSession(total: total, sessions: sessions)
        longestStreak = window.longestStreak(in: segments)

        // favourites
        songsLiked = likes.count
        topShows = window.topShows(in: segments)
        topArtists = Self.topArtists(from: likes)
    }
}
