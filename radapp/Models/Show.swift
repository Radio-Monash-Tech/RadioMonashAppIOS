import Foundation

struct ShowSeries: Identifiable, Hashable {
    let id: String
    var title: String
    var hosts: [String]
    var summary: AttributedString?

    var hostLine: String? {
        hosts.isEmpty ? nil : ListFormatter.localizedString(byJoining: hosts)
    }
}

struct ScheduledShow: Identifiable, Hashable {
    let id: String
    let series: ShowSeries
    let start: Date
    let end: Date

    func isOnAir(at date: Date = .now) -> Bool { start <= date && date < end }

    var timeRange: String { "\(Self.clock(start)) – \(Self.clock(end))" }

    var dayLabel: String {
        start.formatted(Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).weekday(.abbreviated).day().month(.abbreviated))
    }

    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = Calendar.melbourne.timeZone
        return formatter
    }()
}
