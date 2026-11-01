import SwiftUI

// searches shows, articles and recently played tracks
struct SearchView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @EnvironmentObject private var journalism: JournalismStore
    @State private var query = ""
    @Environment(\.isLandscapePhone) private var isLandscape

    // the search without spaces at the ends
    private var trimmed: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    // shows whose title or a host matches
    private var shows: [ShowSeries] {
        schedule.series.filter { series in
            series.title.localizedCaseInsensitiveContains(trimmed)
                || series.hosts.contains { host in
                    host.localizedCaseInsensitiveContains(trimmed)
                }
        }
    }

    // articles whose title or author matches
    private var articles: [Article] {
        journalism.articles.filter { article in
            article.title.localizedCaseInsensitiveContains(trimmed)
                || article.author.localizedCaseInsensitiveContains(trimmed)
        }
    }

    // played songs whose title or artist matches
    private var tracks: [PlayedTrack] {
        player.history.filter { track in
            track.title.localizedCaseInsensitiveContains(trimmed)
                || track.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmed.isEmpty {
                    ContentUnavailableView(
                        "Search Radio Monash",
                        systemImage: "magnifyingglass",
                        description: Text("Find shows, articles, and recently played tracks.")
                    )
                } else if shows.isEmpty && articles.isEmpty && tracks.isEmpty {
                    ContentUnavailableView.search(text: trimmed)
                } else {
                    results
                }
            }
            .navigationTitle("Search")
            // load both at the same time
            .task {
                async let scheduleLoad: Void = schedule.loadIfNeeded()
                async let articlesLoad: Void = journalism.loadIfNeeded()
                _ = await (scheduleLoad, articlesLoad)
            }
            .navigationDestination(for: ShowSeries.self) { series in
                ShowDetailView(series: series)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleView(article: article)
            }
        }
        .searchable(text: $query, prompt: "Shows, articles, tracks")
    }

    @ViewBuilder
    private var results: some View {
        if isLandscape {
            // each kind of result gets its own column
            HStack(spacing: 0) {
                if !shows.isEmpty {
                    List {
                        showsSection
                    }
                }
                if !articles.isEmpty {
                    List {
                        articlesSection
                    }
                }
                if !tracks.isEmpty {
                    List {
                        tracksSection
                    }
                }
            }
        } else {
            List {
                if !shows.isEmpty {
                    showsSection
                }
                if !articles.isEmpty {
                    articlesSection
                }
                if !tracks.isEmpty {
                    tracksSection
                }
            }
        }
    }

    private var showsSection: some View {
        Section("Shows") {
            ForEach(shows) { series in
                NavigationLink(value: series) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(series.title).font(.body.weight(.semibold))
                        if let hosts = series.hostLine {
                            Text(hosts)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var articlesSection: some View {
        Section("Articles") {
            ForEach(articles) { article in
                NavigationLink(value: article) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title).font(.body.weight(.semibold))
                        ArticleByline(article: article)
                    }
                }
            }
        }
    }

    private var tracksSection: some View {
        Section("Tracks Played") {
            ForEach(tracks) { track in
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                    Text("\(track.artist) · \(track.playedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .environmentObject(JournalismStore())
}
