import Foundation

// the station's calendar, so days and weeks follow melbourne time on every phone
extension Calendar {
    // built once, the first time it's used
    static let melbourne: Calendar = {
        // gregorian even if the phone uses another calendar
        var calendar = Calendar(identifier: .gregorian)
        // melbourne time, daylight saving switches automatically
        calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        calendar.locale = Locale(identifier: "en_AU")
        // weeks start on monday (1 is sunday)
        calendar.firstWeekday = 2
        return calendar
    }()
}
