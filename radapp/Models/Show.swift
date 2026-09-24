import Foundation

struct ShowSeries: Identifiable, Hashable {
    let id: String
    var title: String
    var host: String
    var genres: String
    var summary: String
    var startHour: Int
    var durationHours: Int

    var timeslot: String {
        String(format: "%02d:00 – %02d:00", startHour, (startHour + durationHours) % 24)
    }
}

struct ScheduledShow: Identifiable, Hashable {
    let series: ShowSeries
    let start: Date
    let end: Date

    var id: String { "\(series.id)-\(Int(start.timeIntervalSince1970))" }

    func isOnAir(at date: Date = .now) -> Bool { start <= date && date < end }

    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = Calendar.melbourne.timeZone
        return formatter
    }()
}
