import SwiftUI

/// The captions from this listen, oldest first: the same lines the Live
/// screen keeps, so you can scroll back and search them. Nothing is saved to
/// the iPhone, so they go when captions restart or the app closes. A long
/// press copies or shares a line as a quote.
struct TranscriptView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @State private var search = ""

    private var captions: CaptionCoordinator { player.captions }

    private var allLines: [CaptionLine] {
        captions.lines + (captions.liveLine.map { [$0] } ?? [])
    }

    private var results: [CaptionLine] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allLines }
        return allLines.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Section {
                ForEach(results) { line in
                    TranscriptRow(line: line, highlight: search)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = line.text
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            if case .host(let show) = line.speaker {
                                Button {
                                    SystemPresenter.share("“\(line.text)”\n— \(show) on Radio Monash")
                                } label: {
                                    Label("Share Quote", systemImage: "quote.bubble")
                                }
                            }
                        }
                }
            } footer: {
                if !allLines.isEmpty {
                    Text("Only the latest captions are kept, and nothing is saved to this iPhone.")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search what was said")
        .overlay {
            if allLines.isEmpty {
                ContentUnavailableView(
                    "No Captions Yet",
                    systemImage: "captions.bubble",
                    description: Text("Turn on CC while the radio plays, and the latest captions appear here. Nothing is saved to this iPhone.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }
}

private struct TranscriptRow: View {
    let line: CaptionLine
    let highlight: String

    private var isLyric: Bool {
        if case .lyrics = line.speaker { true } else { false }
    }

    private var source: String {
        switch line.speaker {
        case .host(let show): show
        case .lyrics(let track): track
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                KindPill(isLyric: isLyric)
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(highlighted)
                .font(isLyric ? .subheadline.italic() : .body)
                .foregroundStyle(isLyric ? .secondary : .primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// The text with every search match marked.
    private var highlighted: AttributedString {
        var text = AttributedString(line.text)
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
    let isLyric: Bool

    var body: some View {
        Text(isLyric ? "Lyrics" : "Talk")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(isLyric ? Color.green : Color.orange, in: Capsule())
    }
}

#Preview {
    NavigationStack {
        TranscriptView()
    }
    .environmentObject(RadioPlayerModel())
}
