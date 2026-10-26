import SwiftUI

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
    // When `track` is set, opens its Song.link page in an in-app browser, then
    // resets `track` to nil. The page lists the song on every streaming service
    // and has its own share options. Songs iTunes doesn't have get no page, so
    // those show an alert instead.
    func trackShareSheet(for track: Binding<ShareableTrack?>) -> some View {
        task(id: track.wrappedValue) {
            guard let shared = track.wrappedValue else { return }
            do {
                let match = try await ITunesClient.shared.track(title: shared.title, artist: shared.artist)
                guard !Task.isCancelled else { return }
                if let match {
                    SystemPresenter.openInApp(match.songLinkURL)
                } else {
                    SystemPresenter.alert(title: "Can't Find This Track")
                }
            } catch {
                guard !Task.isCancelled else { return }
                SystemPresenter.alert(title: "Couldn't Look Up This Track", message: error.localizedDescription)
            }
            // Cleared so tapping Share on the same song again counts as a new request.
            track.wrappedValue = nil
        }
    }
}
