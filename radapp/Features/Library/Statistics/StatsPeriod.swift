import Foundation

// week, month or year
enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month, year

    var id: Self {
        self
    }

    var label: String {
        switch self {
        case .week:
            "Week"
        case .month:
            "Month"
        case .year:
            "Year"
        }
    }

    // the calendar unit for the whole period
    var component: Calendar.Component {
        switch self {
        case .week:
            .weekOfYear
        case .month:
            .month
        case .year:
            .year
        }
    }

    // the calendar unit for one bar: a day, or a month in the year view
    var bucketComponent: Calendar.Component {
        switch self {
        case .week, .month:
            .day
        case .year:
            .month
        }
    }
}
