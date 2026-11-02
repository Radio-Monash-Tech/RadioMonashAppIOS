import SwiftUI

struct TopShowsCard: View {
    let shows: [ListeningStats.ShowTotal]
    // finds the show's page, nil if it can't be opened
    let series: (ListeningStats.ShowTotal) -> ShowSeries?
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.accentChoice) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader("Top shows") {
                EmptyView()
            }

            ForEach(Array(shows.enumerated()), id: \.element.id) { rank, show in
                // only rows with a page are links
                if let series = series(show) {
                    NavigationLink(value: series) {
                        row(rank: rank, show: show, isLink: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    row(rank: rank, show: show, isLink: false)
                }
            }
        }
        .statsCard()
    }

    // rank, name, time and a bar sized against the top show
    private func row(rank: Int, show: ListeningStats.ShowTotal, isLink: Bool) -> some View {
        let fraction = show.seconds / max(shows.first?.seconds ?? 1, 1)
        return HStack(spacing: 12) {
            Text("\(rank + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(show.name)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(ListeningDuration.format(show.seconds))
                        .font(.subheadline.monospaced())
                        .foregroundStyle(.secondary)
                }
                // grey track with the coloured bar on top
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(rank == 0 ? accent.color : accent.color.opacity(0.4))
                                .frame(width: max(6, proxy.size.width * fraction))
                        }
                    }
                    .accessibilityHidden(true)
            }

            // hidden, not removed, so every row lines up
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .opacity(isLink ? 1 : 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
