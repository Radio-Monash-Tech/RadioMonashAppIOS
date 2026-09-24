import SwiftUI

struct FollowedShowsView: View {
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()

    private var shows: [ShowSeries] {
        SampleContent.series.filter { followed.contains($0.id) }
    }

    var body: some View {
        Group {
            if shows.isEmpty {
                ContentUnavailableView(
                    "No Followed Shows",
                    systemImage: "bell",
                    description: Text("Follow a show from the Schedule and it will appear here, with a reminder before it goes to air.")
                )
            } else {
                List {
                    ForEach(shows) { series in
                        NavigationLink(value: series) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(series.title).font(.body.weight(.semibold))
                                Text("\(series.host) · \(series.timeslot)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { followed.toggle(shows[index].id) }
                    }
                }
            }
        }
        .navigationTitle("Followed Shows")
    }
}
