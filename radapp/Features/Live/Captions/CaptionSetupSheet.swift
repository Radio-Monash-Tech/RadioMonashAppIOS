import SwiftUI

/// Shown the first time captions turn on: what they are, that nothing
/// leaves the phone, and the one-off speech model download.
struct CaptionSetupSheet: View {
    let captions: CaptionCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentChoice) private var accent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 48))
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
                    point("text.page", "A transcript you can search",
                          "What presenters say is kept for two weeks so you can find a gig date or band name later. Lyrics aren't kept.")
                    point("exclamationmark.bubble", "Made automatically",
                          "Captions may get some words wrong, especially names and sung lyrics.")
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) { actions }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch captions.availability {
            case .needsDownload:
                Button {
                    Task { await captions.downloadModel() }
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
