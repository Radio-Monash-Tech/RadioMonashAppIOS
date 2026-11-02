import Foundation

// MARK: - Show series

// a radio show, whatever day it's on
struct ShowSeries: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var hosts: [String]
    var summary: AttributedString?

    // "Alex, Sam and Jo", nil when there are no hosts
    var hostLine: String? {
        if hosts.isEmpty {
            return nil
        }
        return ListFormatter.localizedString(byJoining: hosts)
    }
}

// MARK: - Scheduled show

// one episode on the schedule
struct ScheduledShow: Identifiable, Hashable, Codable {
    let id: String
    let series: ShowSeries
    let start: Date
    let end: Date

    func isOnAir(at date: Date = .now) -> Bool {
        start <= date && date < end
    }

    // "09:00 – 10:00"
    var timeRange: String {
        "\(Self.clock(start)) – \(Self.clock(end))"
    }

    // "Mon 3 Nov", in melbourne time
    var dayLabel: String {
        start.formatted(Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).weekday(.abbreviated).day().month(.abbreviated))
    }

    // "09:00", in melbourne time
    static func clock(_ date: Date) -> String {
        clockFormatter.string(from: date)
    }

    // made once, since formatters are slow to create
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = Calendar.melbourne.timeZone
        return formatter
    }()
}
