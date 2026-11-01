import SwiftUI

// the schedule tab: a day picker and that day's shows
struct ScheduleView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.accentChoice) private var accent
    @State private var selectedDay = Calendar.melbourne.startOfDay(for: .now)
    // updated every minute so the on-air row moves on
    @State private var now = Date()
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()
    @Environment(\.isLandscapePhone) private var isLandscape

    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    // days become a sidebar so the shows get the full height
                    HStack(spacing: 0) {
                        DayStrip(days: schedule.week, selection: $selectedDay, axis: .vertical)
                            .frame(width: 76)
                        showList
                    }
                } else {
                    showList
                }
            }
            .navigationTitle("Schedule")
            .refreshable {
                await schedule.load()
            }
            .task {
                await schedule.loadIfNeeded()
            }
            // tick once a minute
            .task {
                while !Task.isCancelled {
                    now = Date()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            .navigationDestination(for: ShowSeries.self) { series in
                ShowDetailView(series: series)
            }
        }
    }

    private var showList: some View {
        List {
            if !isLandscape {
                DayStrip(days: schedule.week, selection: $selectedDay)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            // showing the saved copy because loading failed
            if let savedAt = schedule.offlineCopyDate {
                OfflineNote(savedAt: savedAt)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            content
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        let shows = schedule.shows(on: selectedDay)

        if shows.isEmpty {
            switch schedule.phase {
            case .idle, .loading:
                // grey placeholder rows while loading
                ForEach(0..<6, id: \.self) { index in
                    ScheduleRow(show: .placeholder(index), isOnAir: false)
                        .redacted(reason: .placeholder)
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Schedule Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task {
                            await schedule.load()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .listRowSeparator(.hidden)
            case .loaded:
                ContentUnavailableView(
                    "Nothing Scheduled",
                    systemImage: "music.note.list",
                    description: Text("No shows are on this day. The Radio Monash playlist keeps playing on the Live tab.")
                )
                .listRowSeparator(.hidden)
            }
        } else {
            ForEach(shows) { show in
                let isOnAir = show.isOnAir(at: now)
                let isFollowed = followed.contains(show.series.id)
                NavigationLink(value: show.series) {
                    ScheduleRow(show: show, isOnAir: isOnAir, isFollowed: isFollowed)
                }
                // the show on air is tinted
                .listRowBackground(isOnAir ? accent.color.opacity(0.12) : nil)
                // swipe to follow or unfollow
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        followed.toggle(show.series.id)
                    } label: {
                        Label(isFollowed ? "Unfollow" : "Follow",
                              systemImage: isFollowed ? "bell.slash.fill" : "bell.fill")
                    }
                    .tint(isFollowed ? .gray : accent.color)
                }
            }
            .sensoryFeedback(.success, trigger: followed.ids.count)
        }
    }
}

// the row of day chips, across in portrait and down in landscape
private struct DayStrip: View {
    let days: [Date]
    @Binding var selection: Date
    var axis: Axis = .horizontal

    private var isHorizontal: Bool {
        axis == .horizontal
    }

    private var stack: AnyLayout {
        if isHorizontal {
            return AnyLayout(HStackLayout(spacing: 8))
        }
        return AnyLayout(VStackLayout(spacing: 8))
    }

    private var scrollAxis: Axis.Set {
        if isHorizontal {
            return .horizontal
        }
        return .vertical
    }

    var body: some View {
        ScrollView(scrollAxis, showsIndicators: false) {
            stack {
                ForEach(days, id: \.self) { day in
                    let isSelected = Calendar.melbourne.isDate(day, inSameDayAs: selection)
                    Button {
                        selection = day
                    } label: {
                        // "MON" over "3"
                        VStack(spacing: 2) {
                            Text(day, format: Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).weekday(.abbreviated))
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                            Text(day, format: Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).day())
                                .font(.headline)
                        }
                        .frame(width: 48, height: 52)
                        // fixed-size chips, so the text stops growing once it won't fit
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(isHorizontal ? .horizontal : .vertical, 16)
            .frame(maxWidth: isHorizontal ? nil : .infinity)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// start and end times, title, on-air badge and hosts
private struct ScheduleRow: View {
    let show: ScheduledShow
    let isOnAir: Bool
    var isFollowed = false
    @Environment(\.dynamicTypeSize) private var typeSize
    // wide enough for "00:00", so every row's titles line up
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = 48

    // at the largest text sizes the times go above the title
    private var layout: AnyLayout {
        if typeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
        }
        return AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        layout {
            if typeSize.isAccessibilitySize {
                Text(show.timeRange)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScheduledShow.clock(show.start))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(ScheduledShow.clock(show.end))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: timeWidth, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(show.series.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                    if isOnAir {
                        OnAirBadge()
                    }
                    if isFollowed {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Following")
                    }
                }
                if let hosts = show.series.hostLine {
                    Text(hosts)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private extension ScheduledShow {
    // a fake hour-long show for the loading rows
    static func placeholder(_ index: Int) -> ScheduledShow {
        let start = Calendar.melbourne.date(byAdding: .hour, value: 9 + index, to: Calendar.melbourne.startOfDay(for: .now)) ?? .now
        return ScheduledShow(
            id: "placeholder-\(index)",
            series: ShowSeries(id: "placeholder-\(index)", title: "Loading show title", hosts: ["Presenter"]),
            start: start,
            end: start.addingTimeInterval(3600)
        )
    }
}

// the accent-coloured ON AIR pill
struct OnAirBadge: View {
    @Environment(\.accentChoice) private var accent

    var body: some View {
        Text("ON AIR")
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent.onColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accent.color, in: Capsule())
            .accessibilityLabel("On air now")
    }
}

#Preview {
    ScheduleView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
}
