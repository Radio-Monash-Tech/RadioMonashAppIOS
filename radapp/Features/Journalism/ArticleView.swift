import SwiftUI

struct ArticleView: View {
    let article: Article

    @AppStorage(StoredIDs.savedArticlesKey) private var saved = StoredIDs()
    @AppStorage("readerTextSize") private var textSize: ReaderTextSize = .standard

    private var isSaved: Bool { saved.contains(article.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ArtworkImage(url: nil)
                    .aspectRatio(16 / 10, contentMode: .fit)

                VStack(alignment: .leading, spacing: 12) {
                    Text(article.isFeature ? "FEATURE" : article.category.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)

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

                    ForEach(article.body, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(5)
                    }
                    .dynamicTypeSize(textSize.dynamicTypeSize)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .navigationBarTitleDisplayMode(.inline)
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

                Button {
                    saved.toggle(article.id)
                } label: {
                    Label(isSaved ? "Remove from Saved" : "Save Article",
                          systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }

                if let url = URL(string: "https://www.radiomonash.online/") {
                    ShareLink(item: url, subject: Text(article.title), message: Text(article.title))
                }
            }
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
        ArticleView(article: SampleContent.articles[0])
    }
}
