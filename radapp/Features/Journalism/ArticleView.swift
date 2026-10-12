import SwiftUI
import SwiftData

struct ArticleView: View {
    let article: Article

    @Environment(\.modelContext) private var modelContext
    @Query private var savedArticles: [SavedArticle]
    @AppStorage("readerTextSize") private var textSize: ReaderTextSize = .standard
    @State private var blocks: [ArticleBlock]?

    private var savedCopy: SavedArticle? {
        savedArticles.first { $0.articleID == article.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.system(.title, design: .serif, weight: .bold))

                    HStack(spacing: 10) {
                        Text(article.authorInitials)
                            .font(.caption.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(.fill.tertiary, in: Circle())
                        VStack(alignment: .leading, spacing: 0) {
                            Text(article.author).font(.subheadline.weight(.semibold))
                            Text("\(article.publishedAt.formatted(.dateTime.day().month(.abbreviated).year())) · \(article.readMinutes) min read")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    if let blocks {
                        ForEach(blocks.indices, id: \.self) { index in
                            ArticleBlockView(block: blocks[index])
                        }
                        .dynamicTypeSize(textSize.dynamicTypeSize)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard blocks == nil else { return }
            blocks = contentBlocks()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Text Size", selection: $textSize) {
                        ForEach(ReaderTextSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                } label: {
                    Label("Text Size", systemImage: "textformat.size")
                }

                Button(action: toggleSaved) {
                    Label(savedCopy == nil ? "Save Article" : "Remove from Saved",
                          systemImage: savedCopy == nil ? "bookmark" : "bookmark.fill")
                }
                .sensoryFeedback(.success, trigger: savedCopy != nil) { _, isSaved in isSaved }

                ShareLink(
                    item: article.webURL ?? SquarespaceClient.siteURL,
                    subject: Text(article.title),
                    message: Text(article.title)
                )
            }
        }
    }

    private func contentBlocks() -> [ArticleBlock] {
        let heroKey = article.imageURL?.absoluteString.components(separatedBy: "?").first
        return ArticleHTMLParser.blocks(from: article.bodyHTML).filter { block in
            guard case .image(let url, nil) = block else { return true }
            return url.absoluteString.components(separatedBy: "?").first != heroKey
        }
    }

    private func toggleSaved() {
        modelContext.toggleSaved(article, existing: savedCopy)
    }
}

private struct ArticleBlockView: View {
    let block: ArticleBlock

    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(.body, design: .serif))
                .lineSpacing(5)
        case .heading(let text, let level):
            Text(text)
                .font(.system(level == 1 ? .title2 : level == 2 ? .title3 : .headline, design: .serif, weight: .bold))
                .padding(.top, 8)
        case .quote(let text):
            Text(text)
                .font(.system(.title3, design: .serif))
                .italic()
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.tint).frame(width: 3)
                }
        case .listItem(let text, let marker):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker).monospacedDigit()
                Text(text)
            }
            .font(.system(.body, design: .serif))
            .lineSpacing(5)
        case .image(let url, let caption):
            VStack(alignment: .leading, spacing: 6) {
                CachedArtwork(url: url.squarespaceSized(1000)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Rectangle()
                        .fill(.fill.tertiary)
                        .frame(height: 220)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                if let caption {
                    if caption.characters.count > 140 {
                        Text(caption)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(5)
                            .padding(.top, 6)
                    } else {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

enum ReaderTextSize: String, CaseIterable, Identifiable {
    case small, standard, large, extraLarge
    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "Small"
        case .standard: "Standard"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .medium
        case .standard: .large
        case .large: .xLarge
        case .extraLarge: .xxLarge
        }
    }
}

#Preview {
    NavigationStack {
        ArticleView(article: .placeholder(0))
    }
    .modelContainer(for: SavedArticle.self, inMemory: true)
}
