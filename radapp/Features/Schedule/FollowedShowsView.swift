import SwiftUI

// the shows the user follows, with when each is next on
struct FollowedShowsView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()

    // followed shows that are on this week's schedule
    private var shows: [ShowSeries] {
        schedule.series.filter { series in
            followed.contains(series.id)
        }
    }

    // followed shows that aren't on this week
    private var offScheduleCount: Int {
        followed.ids.count - shows.count
    }

    private var offScheduleNote: String {
        if offScheduleCount == 1 {
            return "1 followed show isn't on this week's schedule."
        }
        return "\(offScheduleCount) followed shows aren't on this week's schedule."
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
                        // swipe to unfollow
                        .onDelete { offsets in
                            for index in offsets {
                                followed.toggle(shows[index].id)
                            }
                        }
                    } footer: {
                        if schedule.phase == .loaded && offScheduleCount > 0 {
                            Text(offScheduleNote)
                        }
                    }
                }
            }
        }
        .navigationTitle("Followed Shows")
        .task {
            await schedule.loadIfNeeded()
        }
    }
}
