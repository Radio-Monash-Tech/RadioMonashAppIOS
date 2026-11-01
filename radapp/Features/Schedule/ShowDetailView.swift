import SwiftUI

// one show: hosts, follow, listen live, about and this week's times
struct ShowDetailView: View {
    let series: ShowSeries

    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()

    private var isFollowed: Bool {
        followed.contains(series.id)
    }

    private var reminderNote: String {
        if isFollowed {
            return "You'll get a reminder 10 minutes before each episode."
        }
        return "Follow to get a reminder 10 minutes before each episode."
    }

    var body: some View {
        // redraws every minute so on air stays right
        TimelineView(.everyMinute) { context in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(series.title)
                            .font(.title.bold())
                        if let hosts = series.hostLine {
                            Text("with \(hosts)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    Button {
                        followed.toggle(series.id)
                    } label: {
                        Label(isFollowed ? "Following" : "Follow",
                              systemImage: isFollowed ? "bell.fill" : "bell")
                    }
                    // haptic only when following
                    .sensoryFeedback(.success, trigger: isFollowed) { _, new in
                        new
                    }

                    // only while this show is on air
                    if schedule.onAir(at: context.date)?.series.id == series.id {
                        Button {
                            if player.state != .playing {
                                player.togglePlayback()
                            }
                        } label: {
                            Label("Listen Live", systemImage: "play.fill")
                        }
                    }
                } footer: {
                    Text(reminderNote)
                }

                if let summary = series.summary {
                    Section("About") {
                        Text(summary)
                    }
                }

                Section("This Week") {
                    let occurrences = schedule.occurrences(of: series.id)
                    if occurrences.isEmpty {
                        Text("Not on the schedule this week.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(occurrences) { show in
                            LabeledContent {
                                if show.isOnAir(at: context.date) {
                                    OnAirBadge()
                                } else {
                                    Text(show.timeRange).monospacedDigit()
                                }
                            } label: {
                                Text(show.dayLabel)
                            }
                            // past episodes are greyed out
                            .foregroundStyle(show.end <= context.date ? .secondary : .primary)
                        }
                    }
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationBarTitleDisplayMode(.inline)
    }
}
