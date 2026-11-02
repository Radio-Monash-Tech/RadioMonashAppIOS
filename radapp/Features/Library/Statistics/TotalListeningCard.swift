import SwiftUI

// the big card: total time, trend and the bar chart
struct TotalListeningCard: View {
    let stats: ListeningStats
    // @Binding property wrapper, reads and writes a value owned by another view
    @Binding var selection: Int?
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.accentChoice) private var accent

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total Listening")
                    .textCase(.uppercase)
                    .font(.footnote.weight(.semibold))
                    .tracking(1)
                Spacer()
                Text(stats.periodLabel)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            total
                .padding(.top, 8)

            if let trend = stats.trend {
                trendLabel(trend)
                    .padding(.top, 6)
            }

            ListeningBarChart(
                buckets: stats.buckets,
                average: stats.average,
                selection: selection ?? stats.currentBucket,
                select: { index in
                    selection = index
                }
            )
            // a new chart per period, so the bars grow in again
            .id(stats.period)
            .padding(.top, 20)
        }
        .statsCard()
    }

    // MARK: - Parts

    // "6h 05m" in big numbers
    private var total: some View {
        let minutes = Int(stats.total / 60)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(minutes / 60)").font(.system(size: 60, weight: .bold))
            Text("h").font(.title.weight(.medium)).foregroundStyle(.secondary)
                .padding(.trailing, 10)
            Text(String(format: "%02d", minutes % 60)).font(.system(size: 60, weight: .bold))
            Text("m").font(.title.weight(.medium)).foregroundStyle(.secondary)
        }
        .monospacedDigit()
        .lineLimit(1)
        // shrinks instead of wrapping at large text sizes
        .minimumScaleFactor(0.5)
        // voiceover reads "6 hours, 5 minutes"
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total listening, \(Duration.seconds(stats.total).formatted(.units(allowed: [.hours, .minutes], width: .wide)))")
    }

    // "↑ 1h 20m more than last week"
    private func trendLabel(_ trend: ListeningStats.Trend) -> some View {
        let last = "last \(stats.period.label.lowercased())"
        let (icon, text, isUp): (String?, String, Bool) = switch trend {
        case .more(let seconds):
            ("arrow.up", "\(ListeningDuration.format(seconds)) more than \(last)", true)
        case .less(let seconds):
            ("arrow.down", "\(ListeningDuration.format(seconds)) less than \(last)", false)
        case .same:
            (nil, "About the same as \(last)", false)
        case .startedListening(let date):
            ("arrow.up", startedText(date), true)
        }
        return HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.caption.weight(.bold))
            }
            Text(text)
        }
        .font(.subheadline.weight(.medium))
        // accent colour when it went up
        .foregroundStyle(isUp ? accent.color : .secondary)
    }

    private func startedText(_ date: Date) -> String {
        let format = Date.FormatStyle(timeZone: Calendar.melbourne.timeZone)
        return switch stats.period {
        case .week:
            "Since you started listening on \(date.formatted(format.weekday(.wide)))"
        case .month:
            "Since you started listening on \(date.formatted(format.day().month(.wide)))"
        case .year:
            "Since you started listening in \(date.formatted(format.month(.wide)))"
        }
    }
}
