import Foundation

extension Calendar {
    static let melbourne: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Melbourne")!
        calendar.locale = Locale(identifier: "en_AU")
        calendar.firstWeekday = 2
        return calendar
    }()
}
