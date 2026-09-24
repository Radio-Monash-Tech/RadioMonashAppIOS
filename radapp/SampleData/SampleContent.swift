import Foundation

// Placeholder content for the Schedule and Journalism tabs until the RadioCult
// schedule endpoint (Stage 4) and the Squarespace journalism feed (Stage 5)
// are wired up. The model types in Models/ are shaped after those
// responses, so only this file should need replacing.

enum SampleContent {

    static let series: [ShowSeries] = [
        ShowSeries(id: "rise-and-whine", title: "Rise & Whine", host: "Tom Okafor", genres: "Talk · Breakfast",
                   summary: "Campus news, bad coffee takes and the day's first tracks to get you to your 8am.",
                   startHour: 7, durationHours: 2),
        ShowSeries(id: "second-coffee", title: "Second Coffee", host: "Priya Raman", genres: "Indie · Dream pop",
                   summary: "Hazy guitars and new releases from Melbourne's independent labels.",
                   startHour: 9, durationHours: 3),
        ShowSeries(id: "afternoon-drift", title: "Afternoon Drift", host: "Kaia Lindqvist", genres: "Ambient · Downtempo",
                   summary: "Slow, textured music for the long stretch between lectures.",
                   startHour: 13, durationHours: 3),
        ShowSeries(id: "local-cuts", title: "Local Cuts", host: "Dev Mathieson", genres: "Melbourne · Live sets",
                   summary: "Live-to-air sets and interviews with bands from around Melbourne.",
                   startHour: 18, durationHours: 2),
        ShowSeries(id: "night-shift", title: "Night Shift", host: "Bo Alvarez", genres: "Electronic",
                   summary: "Club music, deep cuts and long mixes to take you past midnight.",
                   startHour: 21, durationHours: 3),
    ]

    static func schedule(on day: Date) -> [ScheduledShow] {
        let calendar = Calendar.melbourne
        return series.compactMap { series in
            guard let start = calendar.date(bySettingHour: series.startHour, minute: 0, second: 0, of: day),
                  let end = calendar.date(byAdding: .hour, value: series.durationHours, to: start)
            else { return nil }
            return ScheduledShow(series: series, start: start, end: end)
        }
    }

    static let articles: [Article] = [
        Article(
            id: "battle-of-the-bands-returns",
            category: .music,
            title: "Battle of the Bands returns to a campus that nearly lost its stage",
            excerpt: "Six acts, one PA held together with gaffer tape, and the loudest room Clayton has heard since 2019.",
            author: "Harriet Nkomo",
            publishedAt: date(2026, 9, 9),
            readMinutes: 6,
            body: [
                "The Sir John Monash Room was never designed for a five-piece with two amplifiers apiece, which is roughly the point. By eight o'clock the queue had folded back on itself past the loading dock, and the volunteers running the door had stopped bothering with the clicker.",
                "Radio Monash has run Battle of the Bands in some form since the late nineties, but this year was the first since the venue's licence lapsed. Getting it back took eleven weeks of paperwork and one very patient facilities manager.",
                "What the night lacked in polish it made up for in commitment. The winning act, a four-piece who formed in a first-year tutorial, played a twelve-minute closer that nobody asked them to shorten.",
                "The station plans to make the event a fixture again next semester, with heats broadcast live on air.",
            ],
            isFeature: true
        ),
        Article(
            id: "studio-rebuild",
            category: .campus,
            title: "Inside the studio rebuild: what changed and what didn't",
            excerpt: "New desk, same carpet. A tour of the refitted on-air studio.",
            author: "Dev Mathieson",
            publishedAt: date(2026, 9, 5),
            readMinutes: 4,
            body: [
                "The new mixing desk arrived in three boxes and a considerable amount of foam.",
                "Presenters now have a second microphone for guests and a talkback line that no longer hums.",
            ]
        ),
        Article(
            id: "review-tidal-hours",
            category: .reviews,
            title: "Review: Tidal Hours make the quiet parts count",
            excerpt: "A debut that trusts its silences.",
            author: "Priya Raman",
            publishedAt: date(2026, 9, 2),
            readMinutes: 3,
            body: [
                "It's rare for a debut to sound this unhurried.",
                "The record's best moments are the ones where almost nothing happens.",
            ]
        ),
        Article(
            id: "opinion-student-radio",
            category: .opinion,
            title: "Student radio is the last place you can make mistakes on air",
            excerpt: "Why the dead air matters.",
            author: "Kaia Lindqvist",
            publishedAt: date(2026, 8, 28),
            readMinutes: 5,
            body: [
                "Every presenter remembers their first thirty seconds of dead air.",
                "That's the point of a student station: it's allowed to be a rehearsal.",
            ]
        ),
    ]

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.melbourne.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
