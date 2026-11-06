import SwiftUI

// first-time captions intro and the one-off speech model download
struct CaptionSetupSheet: View {
    // MARK: - Inputs

    // the shared caption state
    let captions: CaptionCoordinator
    // closes the sheet
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.dismiss) private var dismiss
    // the app's accent colour
    @Environment(\.accentChoice) private var accent
    // @ScaledMetric property wrapper, grows with the dynamic type text size
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(accent.color)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Text("Live Captions")
                        .font(.title.bold())
                        .frame(maxWidth: .infinity)

                    point("lock.iphone", "Made on your iPhone",
                          "Captions are created on this phone as you listen. No audio is recorded or sent anywhere.")
                    point("music.note", "Lyrics too",
                          "Songs are captioned as well, with swearing masked. Turn this off with Aa if you only want talk.")
                    point("exclamationmark.bubble", "Made automatically",
                          "Captions may get some words wrong, especially names and sung lyrics.")
                }
                .padding(24)
            }
            // the buttons stay pinned to the bottom
            .safeAreaInset(edge: .bottom) {
                actions
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    // download, progress, or turn on, depending on the model
    // @ViewBuilder lets each branch return a different view
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch captions.availability {
            case .needsDownload:
                Button {
                    Task {
                        await captions.downloadModel()
                    }
                } label: {
                    Text("Download Speech Model").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Text("A one-off download from Apple. Wi-Fi recommended.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .downloading(let fraction):
                ProgressView(value: fraction) {
                    Text("Downloading… \(Int(fraction * 100))%")
                        .font(.subheadline)
                }
            default:
                Button {
                    captions.finishSetup()
                    dismiss()
                } label: {
                    Text("Turn On Captions").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            // the download failed
            if let message = captions.errorMessage, captions.availability == .needsDownload {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .controlSize(.large)
        .tint(accent.color)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Helpers

    // one icon, title and explanation
    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(accent.color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
