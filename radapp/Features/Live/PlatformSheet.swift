import SwiftUI

// "Listen on" bottom sheet, styled to match the Android reference app's
// `PlatformLinksBottomSheet` (dark card, platform badges). Apple Music opens
// the exact song; every other service goes through the song's Song.link page.
struct PlatformSheet: View {
    let track: NowPlaying
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var lookup = Lookup.loading
    @State private var attempt = 0

    private enum Lookup {
        case loading
        case found(ITunesTrack)
        case notFound
        case failed
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Listen on")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(track.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(track.artist)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            content
                .frame(minHeight: 176, alignment: .top)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task(id: attempt) {
            lookup = .loading
            do {
                let match = try await ITunesClient.shared.track(title: track.title, artist: track.artist, duration: track.duration)
                lookup = match.map(Lookup.found) ?? .notFound
            } catch {
                lookup = .failed
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch lookup {
        case .loading:
            ProgressView()
                .padding(.top, 48)
        case .found(let match):
            VStack(spacing: 12) {
                rowButton {
                    openURL(match.trackViewURL)
                    dismiss()
                } label: {
                    PlatformRow(title: "Apple Music") {
                        Image("AppleMusicLogo").resizable().scaledToFit()
                    }
                }
                // Kept in the app; the page's platform links still hand off to their apps.
                rowButton {
                    SystemPresenter.openInApp(match.songLinkURL)
                } label: {
                    PlatformRow(title: "Other platforms", subtitle: "Spotify, YouTube Music, Deezer and more") {
                        OtherPlatformsBadge()
                    }
                }
            }
        case .notFound:
            ContentUnavailableView(
                "Not on Streaming Services",
                systemImage: "music.note.list",
                description: Text("Local and student tracks often aren't released online.")
            )
        case .failed:
            ContentUnavailableView {
                Label("Couldn't Load Links", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try Again") { attempt += 1 }
            }
        }
    }

    private func rowButton(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
    }
}

private struct PlatformRow<Icon: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 16) {
            icon
                .frame(width: 48, height: 48)
                // The row's text already names the platform.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

// A 2×2 grid of service logos standing in for Song.link, which has no app icon of its own.
private struct OtherPlatformsBadge: View {
    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                logo("SpotifyLogo")
                logo("DeezerLogo")
            }
            GridRow {
                logo("BandcampLogo")
                Image(systemName: "ellipsis.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func logo(_ name: String) -> some View {
        Image(name).resizable().scaledToFit()
    }
}
