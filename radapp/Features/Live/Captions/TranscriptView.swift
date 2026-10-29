import SwiftUI
import SwiftData

/// Everything captioned in the last two weeks, newest first: talk with the
/// tracks that played in between. Search highlights matches, and a long
/// press copies or shares a line as a quote.
struct TranscriptView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptSegment.startedAt, order: .reverse) private var segments: [TranscriptSegment]
    @State private var search = ""
    @State private var confirmingClear = false

    private var results: [TranscriptSegment] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return segments }
        return segments.filter {
            $0.text.localizedCaseInsensitiveContains(query) || ($0.showName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Sections by day, newest first.
    private var days: [(day: Date, segments: [TranscriptSegment])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: results) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section(day.day.formatted(.dateTime.weekday(.wide).day().month())) {
                    ForEach(day.segments) { segment in
                        TranscriptRow(segment: segment, highlight: search)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = segment.text
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                if segment.kind == .talk {
                                    Button {
                                        SystemPresenter.share(quote(for: segment))
                                    } label: {
                                        Label("Share Quote", systemImage: "quote.bubble")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search what was said")
        .overlay {
            if segments.isEmpty {
                ContentUnavailableView(
                    "No Transcript Yet",
                    systemImage: "captions.bubble",
                    description: Text("Turn on CC while the radio plays, and what's said on air appears here.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", role: .destructive) { confirmingClear = true }
                    .disabled(segments.isEmpty)
            }
        }
        .confirmationDialog("Clear the whole transcript?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear Transcript", role: .destructive) {
                try? modelContext.delete(model: TranscriptSegment.self)
                try? modelContext.save()
            }
        } message: {
            Text("This only removes the text saved on this iPhone.")
        }
    }

    private func quote(for segment: TranscriptSegment) -> String {
        let source = segment.showName.map { "\($0) on Radio Monash" } ?? "Radio Monash"
        return "“\(segment.text)”\n— \(source), \(segment.startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct TranscriptRow: View {
    let segment: TranscriptSegment
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(segment.startedAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                KindPill(kind: segment.kind)
                if let show = segment.showName {
                    Text(show)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Text(highlighted)
                .font(segment.kind == .talk ? .body : .subheadline.italic())
                .foregroundStyle(segment.kind == .talk ? .primary : .secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// The text with every search match marked.
    private var highlighted: AttributedString {
        var text = AttributedString(segment.text)
        let query = highlight.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return text }
        var searchFrom = text.startIndex
        while let range = text[searchFrom...].range(of: query, options: .caseInsensitive) {
            text[range].backgroundColor = .yellow.opacity(0.45)
            searchFrom = range.upperBound
        }
        return text
    }
}

private struct KindPill: View {
    let kind: CaptionMode

    var body: some View {
        Text(kind == .talk ? "Talk" : "Music")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(kind == .talk ? Color.orange : Color.green, in: Capsule())
    }
}

#Preview {
    NavigationStack {
        TranscriptView()
    }
    .modelContainer(for: TranscriptSegment.self, inMemory: true)
}
