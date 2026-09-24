import SwiftUI

struct FollowedShowsView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()

    private var shows: [ShowSeries] {
        schedule.series.filter { followed.contains($0.id) }
    }

    private var offScheduleCount: Int {
        followed.ids.count - shows.count
    }

    var body: some View {
        Group {
            if followed.ids.isEmpty {
                ContentUnavailableView(
                    "No Followed Shows",
                    systemImage: "bell",
                    description: Text("Follow a show from the Schedule and it will appear here, with a reminder before it goes to air.")
                )
            } else {
                List {
                    Section {
                        ForEach(shows) { series in
                            NavigationLink(value: series) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(series.title).font(.body.weight(.semibold))
                                    if let next = schedule.nextOccurrence(of: series.id) {
                                        Text("Next: \(next.dayLabel), \(ScheduledShow.clock(next.start))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { followed.toggle(shows[index].id) }
                        }
                    } footer: {
                        if schedule.phase == .loaded && offScheduleCount > 0 {
                            Text(offScheduleCount == 1
                                 ? "1 followed show isn't on this week's schedule."
                                 : "\(offScheduleCount) followed shows aren't on this week's schedule.")
                        }
                    }
                }
            }
        }
        .navigationTitle("Followed Shows")
        .task { await schedule.loadIfNeeded() }
    }
}
