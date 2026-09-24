import SwiftUI

struct JournalismView: View {
    @State private var category: ArticleCategory?

    private var articles: [Article] {
        guard let category else { return SampleContent.articles }
        return SampleContent.articles.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CategoryChips(selection: $category)

                    if articles.isEmpty {
                        ContentUnavailableView(
                            "Nothing Here Yet",
                            systemImage: "newspaper",
                            description: Text("New \(category?.rawValue.lowercased() ?? "") pieces from the newsroom will appear here.")
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(articles) { article in
                            NavigationLink(value: article) {
                                if article.isFeature {
                                    FeatureCard(article: article)
                                } else {
                                    ArticleRow(article: article)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Journalism")
            .navigationSubtitle("Words from the Radio Monash newsroom")
            .navigationDestination(for: Article.self) { ArticleView(article: $0) }
        }
    }
}

// MARK: - Components

private struct CategoryChips: View {
    @Binding var selection: ArticleCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", isSelected: selection == nil) { selection = nil }
                ForEach(ArticleCategory.allCases) { category in
                    chip(category.rawValue, isSelected: selection == category) { selection = category }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(isSelected ? .accentColor : .secondary)
            .fontWeight(isSelected ? .semibold : .regular)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeatureCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkImage(url: nil)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("FEATURE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tint)
            Text(article.title)
                .font(.title3.bold())
            Text(article.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ArticleByline(article: article)
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.category.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(article.title)
                    .font(.headline)
                    .lineLimit(3)
                ArticleByline(article: article)
            }
            Spacer(minLength: 0)
            ArtworkImage(url: nil)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    JournalismView()
}
