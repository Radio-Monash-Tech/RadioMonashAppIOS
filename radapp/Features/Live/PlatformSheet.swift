import SwiftUI

// MARK: - Platform sheet

// "listen on" sheet: apple music for the exact song, song.link for the rest
struct PlatformSheet: View {
    // MARK: - State

    let track: NowPlaying
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var lookup = Lookup.loading
    // bumped by try again to re-run the lookup
    @State private var attempt = 0

    // where the itunes lookup is up to
    private enum Lookup {
        case loading
        case found(ITunesTrack)
        case notFound
        case failed
    }

    // MARK: - Body

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
        // find the song on itunes
        .task(id: attempt) {
            lookup = .loading
            do {
                let match = try await ITunesClient.shared.track(title: track.title, artist: track.artist, duration: track.duration)
                if let match {
                    lookup = .found(match)
                } else {
                    lookup = .notFound
                }
            } catch {
                lookup = .failed
            }
        }
    }

    // MARK: - Content

    // @ViewBuilder lets each branch return a different view
    @ViewBuilder
    private var content: some View {
        switch lookup {
        case .loading:
            ProgressView()
                .padding(.top, 48)
        case .found(let match):
            VStack(spacing: 12) {
                // opens the apple music app
                rowButton {
                    openURL(match.trackViewURL)
                    dismiss()
                } label: {
                    PlatformRow(title: "Apple Music") {
                        Image("AppleMusicLogo").resizable().scaledToFit()
                    }
                }
                // opens song.link in the app; its links still open other apps
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
                Button("Try Again") {
                    attempt += 1
                }
            }
        }
    }

    // @escaping means the closure is kept and called later
    private func rowButton(action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Platform row

// one service: icon, name, optional subtitle and a chevron
private struct PlatformRow<Icon: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let icon: Icon

    var body: some View {
        HStack(spacing: 16) {
            icon
                .frame(width: 48, height: 48)
                // the text already names the service
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

// MARK: - Other platforms badge

// 2x2 grid of logos, since song.link has no icon of its own
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
