import SwiftUI

enum ScheduleRoute: Hashable { case following }

struct ScheduleView: View {
    @State private var selectedDay = Calendar.melbourne.startOfDay(for: .now)

    private var week: [Date] {
        let calendar = Calendar.melbourne
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        NavigationStack {
            List {
                DayStrip(days: week, selection: $selectedDay)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                // Re-evaluated every minute so the ON AIR marker moves on its own.
                TimelineView(.everyMinute) { context in
                    ForEach(SampleContent.schedule(on: selectedDay)) { show in
                        NavigationLink(value: show.series) {
                            ScheduleRow(show: show, isOnAir: show.isOnAir(at: context.date))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Schedule")
            .navigationSubtitle("Australia/Melbourne · from RadioCult")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Following", value: ScheduleRoute.following)
                }
            }
            .navigationDestination(for: ShowSeries.self) { ShowDetailView(series: $0) }
            .navigationDestination(for: ScheduleRoute.self) { _ in FollowedShowsView() }
        }
    }
}

// MARK: - Day strip

private struct DayStrip: View {
    let days: [Date]
    @Binding var selection: Date

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            .padding(.horizontal, 16)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Row

private struct ScheduleRow: View {
    let show: ScheduledShow
    let isOnAir: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ScheduledShow.clock(show.start))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(ScheduledShow.clock(show.end))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, alignment: .leading)

            ArtworkImage(url: nil)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(show.series.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if isOnAir { OnAirBadge() }
                }
                Text(show.series.host)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(show.series.genres)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isOnAir ? PlayerPalette.live.opacity(0.12) : nil)
    }
}

struct OnAirBadge: View {
    var body: some View {
        Text("ON AIR")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(PlayerPalette.live, in: Capsule())
            .accessibilityLabel("On air now")
    }
}

#Preview {
    ScheduleView()
        .environmentObject(RadioPlayerModel())
}
