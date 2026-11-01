import SwiftUI
import SwiftData

// the screens the library can open
enum LibraryRoute: Hashable {
    case liked, statistics, savedArticles, followedShows, settings
}

// the library tab: a menu of the user's own things
struct LibraryView: View {
    // only read for the counts on each row
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
            // the library's own screens
            .navigationDestination(for: LibraryRoute.self) { route in
                destination(for: route)
            }
            // a show, from followed shows or top shows
            .navigationDestination(for: ShowSeries.self) { series in
                ShowDetailView(series: series)
            }
            // an article, from saved articles
            .navigationDestination(for: Article.self) { article in
                ArticleView(article: article)
            }
        }
    }

    // one menu row with an icon and an optional count on the right
    private func row(_ title: String, systemImage: String, route: LibraryRoute, count: Int? = nil) -> some View {
        NavigationLink(value: route) {
            LabeledContent {
                if let count {
                    Text(count, format: .number)
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: LibraryRoute) -> some View {
        switch route {
        case .liked:
            LikedSongsView()
        case .statistics:
            ListeningStatisticsView()
        case .savedArticles:
            SavedArticlesView()
        case .followedShows:
            FollowedShowsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .modelContainer(for: [FavouriteTrack.self, SavedArticle.self, ListeningSegment.self], inMemory: true)
}
