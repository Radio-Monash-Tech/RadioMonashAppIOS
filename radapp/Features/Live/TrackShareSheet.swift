import SwiftUI
import UIKit

// The parts of a played or liked track needed to share it.
struct ShareableTrack: Equatable {
    let title: String
    let artist: String
}

extension PlayedTrack {
    var shareable: ShareableTrack { ShareableTrack(title: title, artist: artist) }
}

extension FavouriteTrack {
    var shareable: ShareableTrack { ShareableTrack(title: title, artist: artist) }
}

extension View {
    // Shares `track` as its Apple Music link when set, then resets it to nil.
    // Falls back to plain text when the song isn't in the iTunes catalogue.
    func trackShareSheet(for track: Binding<ShareableTrack?>) -> some View {
        modifier(TrackShareModifier(track: track))
    }
}

private struct TrackShareModifier: ViewModifier {
    @Binding var track: ShareableTrack?
    @State private var share: ShareContent?

    func body(content: Content) -> some View {
        content
            // The lookup runs before presenting because the system share sheet
            // can't swap in a link once it's open.
            .task(id: track) {
                guard let track else { return }
                let match = try? await ITunesClient.shared.track(title: track.title, artist: track.artist)
                guard !Task.isCancelled else { return }
                share = ShareContent(track: track, link: match?.trackViewURL)
                self.track = nil
            }
            .sheet(item: $share) { share in
                ActivityView(items: share.activityItems,
                             activities: share.link.map { [OpenInAppleMusicActivity(url: $0)] } ?? [])
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
    }
}

private struct ShareContent: Identifiable {
    let id = UUID()
    let track: ShareableTrack
    let link: URL?

    var activityItems: [Any] {
        let message = "\(track.title) by \(track.artist), heard on Radio Monash"
        return link.map { [message, $0] } ?? [message]
    }
}

// `ShareLink` needs its URL up front, so the share sheet is wrapped directly.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var activities: [UIActivity] = []

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// "Open in Apple Music" row in the share sheet's action list. The link is a
// universal link, so it opens the Music app when installed and Safari otherwise.
private final class OpenInAppleMusicActivity: UIActivity {
    private let url: URL

    init(url: URL) {
        self.url = url
        super.init()
    }

    override var activityType: UIActivity.ActivityType? { .init("edu.monash.radapp.openInAppleMusic") }
    override var activityTitle: String? { "Open in Apple Music" }
    override var activityImage: UIImage? { UIImage(systemName: "music.note") }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { true }

    override func perform() {
        UIApplication.shared.open(url)
        activityDidFinish(true)
    }
}
