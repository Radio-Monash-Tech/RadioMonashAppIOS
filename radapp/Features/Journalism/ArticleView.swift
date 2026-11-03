import SwiftUI
import SwiftData

// MARK: - Article view

// one article, drawn natively from its html
struct ArticleView: View {
    let article: Article

    // MARK: - State

    // the local database, for saving and downloading
    @Environment(\.modelContext) private var modelContext
    // every saved article, kept up to date by swiftdata
    @Query private var savedArticles: [SavedArticle]
    @AppStorage("readerTextSize") private var textSize: ReaderTextSize = .standard
    // nil until the html has been parsed
    @State private var blocks: [ArticleBlock]?
    // the photo open full screen, if any
    @State private var viewerImage: ViewerImage?
    @State private var isDownloading = false
    @State private var downloadFailed = false
    // links each photo to the full-screen viewer for the zoom animation
    @Namespace private var imageNamespace

    // this article's saved copy, if it has been saved
    private var savedCopy: SavedArticle? {
        savedArticles.first { saved in
            saved.articleID == article.id
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.system(.title, design: .serif, weight: .bold))

                    // author initials, name, date and read time
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
                    // voiceover reads the byline as one item
                    .accessibilityElement(children: .combine)

                    if let blocks {
                        ForEach(blocks.indices, id: \.self) { index in
                            ArticleBlockView(block: blocks[index], index: index, imageNamespace: imageNamespace) { url in
                                viewerImage = ViewerImage(id: index, url: url)
                            }
                        }
                        // the reader's text size from the menu
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
            .readableWidthInLandscape()
        }
        .navigationBarTitleDisplayMode(.inline)
        // tapped photo zooms open full screen
        .fullScreenCover(item: $viewerImage) { image in
            ImageViewer(url: image.url)
                .colourVisionFilter()
                .navigationTransition(.zoom(sourceID: image.id, in: imageNamespace))
        }
        // parse the html once
        .task {
            guard blocks == nil else {
                return
            }
            blocks = contentBlocks()
        }
        .alert("Couldn't Download", isPresented: $downloadFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Some photos couldn't be downloaded. The text is still saved. Check your connection and try again.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // text size menu
                Menu {
                    Picker("Text Size", selection: $textSize) {
                        ForEach(ReaderTextSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                } label: {
                    Label("Text Size", systemImage: "textformat.size")
                }

                // save or unsave
                Button(action: toggleSaved) {
                    Label(savedCopy == nil ? "Save Article" : "Remove from Saved",
                          systemImage: savedCopy == nil ? "bookmark" : "bookmark.fill")
                }
                // haptic tap when it becomes saved, not when removed
                .sensoryFeedback(.success, trigger: savedCopy != nil) { _, isSaved in
                    isSaved
                }

                downloadButton

                ShareLink(
                    item: article.webURL ?? SquarespaceClient.siteURL,
                    subject: Text(article.title),
                    message: Text(article.title)
                )
            }
        }
    }

    // MARK: - Saving and downloading

    private func contentBlocks() -> [ArticleBlock] {
        ArticleHTMLParser.blocks(from: article.bodyHTML)
    }

    private func toggleSaved() {
        modelContext.toggleSaved(article, existing: savedCopy)
    }

    // spinner while downloading, remove when downloaded, download otherwise
    @ViewBuilder
    private var downloadButton: some View {
        if isDownloading {
            ProgressView()
                .accessibilityLabel("Downloading")
        } else if let savedCopy, savedCopy.isDownloaded {
            Button {
                modelContext.removeDownload(savedCopy)
            } label: {
                Label("Remove Download", systemImage: "arrow.down.circle.fill")
            }
        } else {
            Button {
                Task {
                    isDownloading = true
                    downloadFailed = await !modelContext.download(article, existing: savedCopy)
                    isDownloading = false
                }
            } label: {
                Label("Download for Offline", systemImage: "arrow.down.circle")
            }
            // haptic tap when the download finishes
            .sensoryFeedback(.success, trigger: savedCopy?.isDownloaded == true) { _, isDownloaded in
                isDownloaded
            }
        }
    }
}

// MARK: - Viewer image

// the photo to show full screen
private struct ViewerImage: Identifiable {
    // the block index, also the zoom animation's source id
    let id: Int
    let url: URL
}

// MARK: - Article block view

// draws one ArticleBlock
private struct ArticleBlockView: View {
    let block: ArticleBlock
    let index: Int
    let imageNamespace: Namespace.ID
    let onImageTap: (URL) -> Void

    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(.body, design: .serif))
                .lineSpacing(5)
        case .heading(let text, let level):
            Text(text)
                .font(.system(headingStyle(level), design: .serif, weight: .bold))
                .padding(.top, 8)
        case .quote(let text):
            // italic with a coloured bar on the left
            Text(text)
                .font(.system(.title3, design: .serif))
                .italic()
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.tint).frame(width: 3)
                }
        case .listItem(let text, let marker):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // same-width digits so numbers line up
                Text(marker).monospacedDigit()
                Text(text)
            }
            .font(.system(.body, design: .serif))
            .lineSpacing(5)
        case .image(let url, let caption):
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    onImageTap(url)
                } label: {
                    CachedArtwork(url: url.squarespaceSized(1000)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(.fill.tertiary)
                            .frame(height: 220)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    // where the full-screen zoom starts from
                    .matchedTransitionSource(id: index, in: imageNamespace)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Image")
                .accessibilityHint("Opens the image full screen")
                if let caption {
                    // long captions are really body text, short ones are small and grey
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

    // level 1 is the biggest
    private func headingStyle(_ level: Int) -> Font.TextStyle {
        switch level {
        case 1:
            .title2
        case 2:
            .title3
        default:
            .headline
        }
    }
}

// MARK: Article Text size


// the reader's text size choices
enum ReaderTextSize: String, CaseIterable, Identifiable {
    case small, standard, large, extraLarge

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .small:
            "Small"
        case .standard:
            "Standard"
        case .large:
            "Large"
        case .extraLarge:
            "Extra Large"
        }
    }
    
    // the dynamic type size each choice uses
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small:
            .medium
        case .standard:
            .large
        case .large:
            .xLarge
        case .extraLarge:
            .xxLarge
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ArticleView(article: .placeholder(0))
    }
    .modelContainer(for: SavedArticle.self, inMemory: true)
}
