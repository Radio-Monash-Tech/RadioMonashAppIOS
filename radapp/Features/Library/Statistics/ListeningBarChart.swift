import Charts
import SwiftUI

// MARK: - Bar chart

// one bar per day (or month), tap or drag to pick one
struct ListeningBarChart: View {
    // MARK: - Inputs

    let buckets: [ListeningStats.Bucket]
    let average: TimeInterval?
    let selection: Int
    let select: (Int) -> Void

    // MARK: - State

    // the bar under the finger, as the chart reports it
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var scrubbed: String?
    // false at first, so the bars can grow up from zero
    @State private var hasGrown = false
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.accentChoice) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Scale

    // the month view has 28-31 thin bars
    private var isDense: Bool {
        buckets.count > 12
    }

    // the chart's top, at least an hour so a few minutes doesn't fill it
    private var maxValue: TimeInterval {
        let tallestBar = buckets.map(\.seconds).max() ?? 0
        return max(tallestBar, average ?? 0, 3600)
    }

    // a short stub for empty days so the bars read as a timeline
    private var stub: TimeInterval {
        maxValue * 0.027
    }

    // gridline spacing: the first step that gives four lines or fewer
    private var gridStep: TimeInterval {
        let hour: TimeInterval = 3600
        let steps = [0.5, 1, 2, 3, 6, 12, 24, 48, 100].map { hours in
            hours * hour
        }
        let fitting = steps.first { step in
            maxValue / step <= 4
        }
        return fitting ?? steps.last!
    }

    private var selectedBucket: ListeningStats.Bucket? {
        // guard exits early if the check fails
        guard buckets.indices.contains(selection) else {
            return nil
        }
        return buckets[selection]
    }

    // MARK: - Body

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", String(bucket.id)),
                    y: .value("Listening", hasGrown ? barValue(bucket) : 0),
                    width: .ratio(isDense ? 0.75 : 0.7)
                )
                .foregroundStyle(color(for: bucket))
                // rounder tops than bottoms, smaller when the bars are thin
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: isDense ? 3 : 5, bottomLeading: 3,
                                                                     bottomTrailing: 3, topTrailing: isDense ? 3 : 5),
                                                  style: .continuous))
                .accessibilityLabel(bucket.title)
                .accessibilityValue(ListeningDuration.format(bucket.seconds))
            }

            // dashed average line
            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        Text("avg \(ListeningDuration.format(average))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            // card-coloured background so it stays readable over bars
                            .background(Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .accessibilityHidden(true)
            }

            // the pop-up above the selected bar
            if let selectedBucket {
                RuleMark(x: .value("Period", String(selectedBucket.id)))
                    .foregroundStyle(accent.color.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .zIndex(-1)
                    .annotation(position: .top, spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        SelectionCallout(title: selectedBucket.title, seconds: selectedBucket.seconds)
                    }
                    .accessibilityHidden(true)
            }
        }
        .chartYScale(domain: 0...maxValue)
        // hour labels on the right
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: gridStep)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                if let seconds = value.as(Double.self), seconds > 0 {
                    AxisValueLabel(hourLabel(seconds))
                }
            }
        }
        // day or month letters along the bottom
        .chartXAxis {
            AxisMarks { value in
                if let id = value.as(String.self).flatMap(Int.init), buckets.indices.contains(id) {
                    AxisValueLabel(centered: true, collisionResolution: .disabled) {
                        Text(buckets[id].axisLabel)
                            .font(.caption)
                            .fontWeight(id == selection ? .semibold : .regular)
                            .foregroundStyle(id == selection ? .primary : .secondary)
                    }
                }
            }
        }
        // tap or drag across the bars
        .chartXSelection(value: $scrubbed)
        .onChange(of: scrubbed) { _, scrubbed in
            // ignore future bars and the one already selected
            guard let id = scrubbed.flatMap(Int.init), buckets.indices.contains(id),
                  !buckets[id].isFuture, id != selection
            else {
                return
            }
            select(id)
        }
        // room above the bars for the pop-up
        .padding(.top, 54)
        .frame(height: 290)
        .animation(.snappy, value: selection)
        // a light tick as the selection moves
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear {
            guard !hasGrown else {
                return
            }
            if reduceMotion {
                hasGrown = true
            } else {
                withAnimation(.smooth(duration: 0.6)) {
                    hasGrown = true
                }
            }
        }
    }

    // MARK: - Helpers

    // never shorter than the stub
    private func barValue(_ bucket: ListeningStats.Bucket) -> TimeInterval {
        if bucket.seconds > 0 {
            return max(bucket.seconds, stub)
        }
        return stub
    }

    // "30m", "1h", "12h"
    private func hourLabel(_ seconds: TimeInterval) -> String {
        if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        }
        return "\(Int(seconds / 3600))h"
    }

    // grey when empty, full accent when selected, faded accent otherwise
    private func color(for bucket: ListeningStats.Bucket) -> Color {
        if bucket.seconds <= 0 {
            return Color(.tertiarySystemFill)
        }
        if bucket.id == selection {
            return accent.color
        }
        return accent.color.opacity(0.4)
    }
}

// MARK: - Selection callout

// "Thursday / 48m" above the selected bar
private struct SelectionCallout: View {
    let title: String
    let seconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(ListeningDuration.format(seconds))
                .font(.headline)
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
