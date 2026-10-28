import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.accentChoice) private var accent
    @State private var selectedDay = Calendar.melbourne.startOfDay(for: .now)
    @State private var now = Date()
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()
    @Environment(\.isLandscapePhone) private var isLandscape

    var body: some View {
        NavigationStack {
            Group {
                if isLandscape {
                    // Days become a sidebar so the shows get the full height.
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
            .refreshable { await schedule.load() }
            .task { await schedule.loadIfNeeded() }
            .task {
                while !Task.isCancelled {
                    now = Date()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            .navigationDestination(for: ShowSeries.self) { ShowDetailView(series: $0) }
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
                    Button("Try Again") { Task { await schedule.load() } }
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
                .listRowBackground(isOnAir ? accent.color.opacity(0.12) : nil)
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

// MARK: - Day strip

private struct DayStrip: View {
    let days: [Date]
    @Binding var selection: Date
    var axis: Axis = .horizontal

    var body: some View {
        let stack = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(spacing: 8))

        ScrollView(axis == .horizontal ? .horizontal : .vertical, showsIndicators: false) {
            stack {
                ForEach(days, id: \.self) { day in
                    let isSelected = Calendar.melbourne.isDate(day, inSameDayAs: selection)
                    Button {
                        selection = day
                    } label: {
                        VStack(spacing: 2) {
                            Text(day, format: Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).weekday(.abbreviated))
                                .font(.caption2.weight(.semibold))
                                .textCase(.uppercase)
                            Text(day, format: Date.FormatStyle(timeZone: Calendar.melbourne.timeZone).day())
                                .font(.headline)
                        }
                        .frame(width: 48, height: 52)
                        // Fixed-size chips: the text stops growing once it would no longer fit.
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
            .padding(axis == .horizontal ? .horizontal : .vertical, 16)
            .frame(maxWidth: axis == .vertical ? .infinity : nil)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Row

private struct ScheduleRow: View {
    let show: ScheduledShow
    let isOnAir: Bool
    var isFollowed = false
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Wide enough for "00:00" at the current text size, so every row's titles line up.
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = 48

    var body: some View {
        // At the largest sizes there's no room beside the title, so the times go above it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
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
                    if isOnAir { OnAirBadge() }
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
