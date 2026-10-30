import Charts
import SwiftUI
import SwiftData

struct ListeningStatisticsView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Query(sort: \ListeningSegment.start) private var segments: [ListeningSegment]
    @Query private var likes: [FavouriteTrack]
    @AppStorage("statisticsPeriod") private var period: StatsPeriod = .week
    @State private var selectedBucket: Int?
    @State private var isConfirmingReset = false

    var body: some View {
        Group {
            if segments.isEmpty {
                ContentUnavailableView {
                    Label("No Listening Yet", systemImage: "chart.bar")
                } description: {
                    Text("Your listening time and top shows will appear here once you've tuned in.")
                } actions: {
                    Text("Statistics are calculated and stored only on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                content(ListeningStats(period: period, segments: segments, likes: likes))
            }
        }
        .navigationTitle("Listening Statistics")
        .confirmationDialog("Reset listening statistics?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Statistics", role: .destructive) { player.resetListeningStatistics() }
        } message: {
            Text("All recorded listening time on this device will be deleted. Liked songs aren't affected.")
        }
        .onChange(of: period) { selectedBucket = nil }
    }

    private func content(_ stats: ListeningStats) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                TotalListeningCard(stats: stats, selection: $selectedBucket)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: stats.sessions.formatted(), label: stats.sessions == 1 ? "Session" : "Sessions")
                    StatTile(value: ListeningDuration.format(stats.averageSession), label: "Average session")
                    StatTile(value: stats.longestStreak == 1 ? "1 day" : "\(stats.longestStreak) days", label: "Longest streak")
                    StatTile(value: stats.songsLiked.formatted(), label: stats.songsLiked == 1 ? "Song liked" : "Songs liked")
                }

                if !stats.topShows.isEmpty {
                    TopShowsCard(shows: stats.topShows, series: series(for:))
                }

                if !stats.topArtists.isEmpty {
                    MostLikedArtistsCard(artists: stats.topArtists)
                }

                Label("Tracked while the stream plays and stored only on this iPhone. Nothing is sent to Radio Monash.",
                      systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                Button {
                    isConfirmingReset = true
                } label: {
                    Text("Reset statistics")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .statsCard(padding: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Opens the show's page. The schedule only covers this week, so older
    /// shows fall back to what was recorded about them.
    private func series(for show: ListeningStats.ShowTotal) -> ShowSeries? {
        if let id = show.seriesID {
            return schedule.series.first { $0.id == id } ?? ShowSeries(id: id, title: show.name, hosts: [], summary: nil)
        }
        return schedule.series.first { $0.title.localizedCaseInsensitiveCompare(show.name) == .orderedSame }
    }
}

// MARK: - Total listening

private struct TotalListeningCard: View {
    let stats: ListeningStats
    @Binding var selection: Int?
    @Environment(\.accentChoice) private var accent

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
                select: { selection = $0 }
            )
            // A fresh chart per period, so the bars grow in again on each switch.
            .id(stats.period)
            .padding(.top, 20)
        }
        .statsCard()
    }

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
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total listening, \(Duration.seconds(stats.total).formatted(.units(allowed: [.hours, .minutes], width: .wide)))")
    }

    private func trendLabel(_ trend: ListeningStats.Trend) -> some View {
        let last = "last \(stats.period.label.lowercased())"
        let (icon, text, isUp): (String?, String, Bool) = switch trend {
        case .more(let seconds): ("arrow.up", "\(ListeningDuration.format(seconds)) more than \(last)", true)
        case .less(let seconds): ("arrow.down", "\(ListeningDuration.format(seconds)) less than \(last)", false)
        case .same: (nil, "About the same as \(last)", false)
        case .startedListening(let date): ("arrow.up", startedText(date), true)
        }
        return HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.caption.weight(.bold)) }
            Text(text)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(isUp ? accent.color : .secondary)
    }

    private func startedText(_ date: Date) -> String {
        let format = Date.FormatStyle(timeZone: Calendar.melbourne.timeZone)
        return switch stats.period {
        case .week: "Since you started listening on \(date.formatted(format.weekday(.wide)))"
        case .month: "Since you started listening on \(date.formatted(format.day().month(.wide)))"
        case .year: "Since you started listening in \(date.formatted(format.month(.wide)))"
        }
    }
}

private struct ListeningBarChart: View {
    let buckets: [ListeningStats.Bucket]
    let average: TimeInterval?
    let selection: Int
    let select: (Int) -> Void
    @State private var scrubbed: String?
    @State private var hasGrown = false
    @Environment(\.accentChoice) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDense: Bool { buckets.count > 12 }
    /// At least an hour, so a few minutes of listening doesn't fill the chart.
    private var maxValue: TimeInterval { max(buckets.map(\.seconds).max() ?? 0, average ?? 0, 3600) }
    /// Empty days still get a short stub so the row of bars reads as a timeline.
    private var stub: TimeInterval { maxValue * 0.027 }

    /// Gridline spacing: the first step that gives four lines or fewer.
    private var gridStep: TimeInterval {
        let hour: TimeInterval = 3600
        let steps = [0.5, 1, 2, 3, 6, 12, 24, 48, 100].map { $0 * hour }
        return steps.first { maxValue / $0 <= 4 } ?? steps.last!
    }

    private var selectedBucket: ListeningStats.Bucket? {
        buckets.indices.contains(selection) ? buckets[selection] : nil
    }

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", String(bucket.id)),
                    y: .value("Listening", hasGrown ? barValue(bucket) : 0),
                    width: .ratio(isDense ? 0.75 : 0.7)
                )
                .foregroundStyle(color(for: bucket))
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: isDense ? 3 : 5, bottomLeading: 3,
                                                                     bottomTrailing: 3, topTrailing: isDense ? 3 : 5),
                                                  style: .continuous))
                .accessibilityLabel(bucket.title)
                .accessibilityValue(ListeningDuration.format(bucket.seconds))
            }

            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        Text("avg \(ListeningDuration.format(average))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            // Card-coloured backing so the label stays readable over bars.
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .accessibilityHidden(true)
            }

            // The pop-up above the selected bar, in place of a separate readout.
            if let selectedBucket {
                RuleMark(x: .value("Period", String(selectedBucket.id)))
                    .foregroundStyle(accent.color.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .zIndex(-1)
                    .annotation(position: .top, spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        SelectionCallout(title: selectedBucket.title, seconds: selectedBucket.seconds)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartYScale(domain: 0...maxValue)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: gridStep)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                if let seconds = value.as(Double.self), seconds > 0 {
                    AxisValueLabel(hourLabel(seconds))
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let id = value.as(String.self).flatMap(Int.init), buckets.indices.contains(id) {
                    AxisValueLabel(centered: true, collisionResolution: .disabled) {
                        Text(buckets[id].axisLabel)
                            .font(.caption)
                            .fontWeight(id == selection ? .semibold : .regular)
                            .foregroundStyle(id == selection ? .primary : .secondary)
                    }
                }
            }
        }
        // Tap or drag across the bars to pick a day (or month).
        .chartXSelection(value: $scrubbed)
        .onChange(of: scrubbed) { _, scrubbed in
            guard let id = scrubbed.flatMap(Int.init), buckets.indices.contains(id),
                  !buckets[id].isFuture, id != selection else { return }
            select(id)
        }
        // Room above the plot for the pop-up.
        .padding(.top, 54)
        .frame(height: 290)
        .animation(.snappy, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear {
            guard !hasGrown else { return }
            if reduceMotion {
                hasGrown = true
            } else {
                withAnimation(.smooth(duration: 0.6)) { hasGrown = true }
            }
        }
    }

    private func barValue(_ bucket: ListeningStats.Bucket) -> TimeInterval {
        bucket.seconds > 0 ? max(bucket.seconds, stub) : stub
    }

    /// "30m", "1h", "12h"
    private func hourLabel(_ seconds: TimeInterval) -> String {
        seconds < 3600 ? "\(Int(seconds / 60))m" : "\(Int(seconds / 3600))h"
    }

    private func color(for bucket: ListeningStats.Bucket) -> Color {
        if bucket.seconds <= 0 { return Color(.tertiarySystemFill) }
        return bucket.id == selection ? accent.color : accent.color.opacity(0.4)
    }
}

/// "Thursday / 48m" above the selected bar.
private struct SelectionCallout: View {
    let title: String
    let seconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ListeningDuration.format(seconds))
                .font(.headline)
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Tiles

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .statsCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Top shows

private struct TopShowsCard: View {
    let shows: [ListeningStats.ShowTotal]
    let series: (ListeningStats.ShowTotal) -> ShowSeries?
    @Environment(\.accentChoice) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            CardHeader("Top shows") { EmptyView() }

            ForEach(Array(shows.enumerated()), id: \.element.id) { rank, show in
                if let series = series(show) {
                    NavigationLink(value: series) { row(rank: rank, show: show, isLink: true) }
                        .buttonStyle(.plain)
                } else {
                    row(rank: rank, show: show, isLink: false)
                }
            }
        }
        .statsCard()
    }

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

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .opacity(isLink ? 1 : 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Most-liked artists

private struct MostLikedArtistsCard: View {
    let artists: [ListeningStats.ArtistLikes]
    @Environment(\.accentChoice) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader("Most-liked artists") {
                NavigationLink("Liked Songs", value: LibraryRoute.liked)
                    .font(.subheadline)
                    .foregroundStyle(accent.color)
            }

            ForEach(artists) { artist in
                HStack(spacing: 14) {
                    Text(artist.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(artist.count) liked")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .statsCard()
    }
}

// MARK: - Shared

private struct CardHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}

private extension View {
    func statsCard(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack { ListeningStatisticsView() }
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(previewContainer())
}

private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(for: ListeningSegment.self, FavouriteTrack.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let calendar = Calendar.melbourne
    let shows = ["Afternoon Drift", "Local Cuts", "Night Shift", "Second Coffee"]
    var generator = SystemRandomNumberGenerator()
    for daysAgo in 0..<240 where Bool.random(using: &generator) {
        guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now)),
              let start = calendar.date(byAdding: .minute, value: Int.random(in: 8 * 60...22 * 60), to: day),
              start < .now else { continue }
        let segment = ListeningSegment(sessionID: UUID(), start: start, showName: shows.randomElement(), seriesID: nil)
        segment.end = min(.now, start.addingTimeInterval(.random(in: 10 * 60...90 * 60)))
        context.insert(segment)
    }
    for (artist, count) in [("Nikau", 5), ("Mellowing", 3), ("Ophelia Grange", 2)] {
        for index in 0..<count {
            context.insert(FavouriteTrack(title: "Track \(index)", artist: artist, artworkURL: nil, showName: nil))
        }
    }
    return container
}
