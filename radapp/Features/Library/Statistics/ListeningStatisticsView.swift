import SwiftUI
import SwiftData

// listening time, chart, tiles, top shows and most-liked artists
struct ListeningStatisticsView: View {
    // MARK: - Data

    // @EnvironmentObject property wrapper, reads a shared object passed down from a parent view
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    // every recorded bit of listening, oldest first
    // @Query macro, loads SwiftData records and keeps them up to date
    @Query(sort: \ListeningSegment.start) private var segments: [ListeningSegment]
    @Query private var likes: [FavouriteTrack]

    // MARK: - State

    // remembered between visits
    // @AppStorage property wrapper, saved in UserDefaults and redraws when it changes
    @AppStorage("statisticsPeriod") private var period: StatsPeriod = .week
    // the bar the user picked, nil means today
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var selectedBucket: Int?
    @State private var isConfirmingReset = false

    // MARK: - Body

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
                // worked out fresh on every redraw
                content(ListeningStats(period: period, segments: segments, likes: likes))
            }
        }
        .navigationTitle("Listening Statistics")
        .confirmationDialog("Reset listening statistics?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Reset Statistics", role: .destructive) {
                player.resetListeningStatistics()
            }
        } message: {
            Text("All recorded listening time on this device will be deleted. Liked songs aren't affected.")
        }
        // a new period starts on today's bar
        .onChange(of: period) {
            selectedBucket = nil
        }
    }

    // MARK: - Content

    private func content(_ stats: ListeningStats) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                TotalListeningCard(stats: stats, selection: $selectedBucket)

                // two columns of small tiles
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

    // MARK: - Helpers

    // the show's page; the schedule only has this week, so older shows use what was recorded
    private func series(for show: ListeningStats.ShowTotal) -> ShowSeries? {
        if let id = show.seriesID {
            let scheduled = schedule.series.first { series in
                series.id == id
            }
            return scheduled ?? ShowSeries(id: id, title: show.name, hosts: [], summary: nil)
        }
        // no id recorded, match by name instead
        return schedule.series.first { series in
            series.title.localizedCaseInsensitiveCompare(show.name) == .orderedSame
        }
    }
}

// MARK: - Preview

// #Preview macro, shows this view in Xcode's canvas
#Preview {
    NavigationStack {
        ListeningStatisticsView()
    }
    .environmentObject(RadioPlayerModel())
    .environmentObject(ScheduleStore())
    .modelContainer(statisticsPreviewContainer())
}
