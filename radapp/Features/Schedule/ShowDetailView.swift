import SwiftUI

struct ShowDetailView: View {
    let series: ShowSeries

    @EnvironmentObject private var player: RadioPlayerModel
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()

    private var isFollowed: Bool { followed.contains(series.id) }

    private var isOnAirNow: Bool {
        SampleContent.schedule(on: .now).contains { $0.series.id == series.id && $0.isOnAir() }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ArtworkImage(url: nil)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(series.title)
                        .font(.title.bold())
                    Text("with \(series.host)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(series.genres)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
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
                .sensoryFeedback(.success, trigger: isFollowed) { _, new in new }

                if isOnAirNow {
                    Button {
                        if player.state != .playing { player.togglePlayback() }
                    } label: {
                        Label("Listen live", systemImage: "play.fill")
                    }
                }
            } footer: {
                Text(isFollowed
                     ? "You'll get a reminder 10 minutes before each episode."
                     : "Follow to get a reminder 10 minutes before each episode.")
            }

            Section("About") {
                Text(series.summary)
                LabeledContent("Airs", value: series.timeslot)
            }
        }
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
