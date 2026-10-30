import SwiftUI
import SwiftData

enum LibraryRoute: Hashable {
    case liked, statistics, savedArticles, followedShows, settings
}

struct LibraryView: View {
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()
    @Query private var likedTracks: [FavouriteTrack]
    @Query private var savedArticles: [SavedArticle]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Liked Songs", systemImage: "heart.fill", route: .liked, count: likedTracks.count)
                    row("Listening Statistics", systemImage: "chart.bar.fill", route: .statistics)
                    row("Saved Articles", systemImage: "bookmark.fill", route: .savedArticles, count: savedArticles.count)
                    row("Followed Shows", systemImage: "bell.fill", route: .followedShows, count: followed.ids.count)
                }
                Section {
                    row("Settings", systemImage: "gearshape", route: .settings)
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: LibraryRoute.self) { destination(for: $0) }
            .navigationDestination(for: ShowSeries.self) { ShowDetailView(series: $0) }
            .navigationDestination(for: Article.self) { ArticleView(article: $0) }
        }
    }

    private func row(_ title: String, systemImage: String, route: LibraryRoute, count: Int? = nil) -> some View {
        NavigationLink(value: route) {
            LabeledContent {
                if let count { Text(count, format: .number) }
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: LibraryRoute) -> some View {
        switch route {
        case .liked: LikedSongsView()
        case .statistics: ListeningStatisticsView()
        case .savedArticles: SavedArticlesView()
        case .followedShows: FollowedShowsView()
        case .settings: SettingsView()
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(for: [FavouriteTrack.self, SavedArticle.self, ListeningSegment.self], inMemory: true)
}
