import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @EnvironmentObject private var journalism: JournalismStore
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private var shows: [ShowSeries] {
        schedule.series.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.hosts.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    private var articles: [Article] {
        journalism.articles.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.author.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var tracks: [PlayedTrack] {
        player.history.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trimmed.isEmpty {
                    ContentUnavailableView(
                        "Search Radio Monash",
                        systemImage: "magnifyingglass",
                        description: Text("Find shows, presenters, articles and tracks played earlier.")
                    )
                } else if shows.isEmpty && articles.isEmpty && tracks.isEmpty {
                    ContentUnavailableView.search(text: trimmed)
                } else {
                    results
                }
            }
            .navigationTitle("Search")
            .task {
                async let scheduleLoad: Void = schedule.loadIfNeeded()
                async let articlesLoad: Void = journalism.loadIfNeeded()
                _ = await (scheduleLoad, articlesLoad)
            }
            .navigationDestination(for: ShowSeries.self) { ShowDetailView(series: $0) }
            .navigationDestination(for: Article.self) { ArticleView(article: $0) }
        }
        .searchable(text: $query, prompt: "Shows, articles, tracks")
    }

    private var results: some View {
        List {
            if !shows.isEmpty {
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
            if !articles.isEmpty {
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
            if !tracks.isEmpty {
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
    }
}

#Preview {
    SearchView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .environmentObject(JournalismStore())
}
