import SwiftUI

// the title and artist needed to share a song
struct ShareableTrack: Equatable {
    let title: String
    let artist: String
}

extension PlayedTrack {
    var shareable: ShareableTrack {
        ShareableTrack(title: title, artist: artist)
    }
}

extension FavouriteTrack {
    var shareable: ShareableTrack {
        ShareableTrack(title: title, artist: artist)
    }
}

extension View {
    // when track is set, opens its song.link page in the app, then clears it
    func trackShareSheet(for track: Binding<ShareableTrack?>) -> some View {
        task(id: track.wrappedValue) {
            guard let shared = track.wrappedValue else {
                return
            }
            do {
                let match = try await ITunesClient.shared.track(title: shared.title, artist: shared.artist)
                guard !Task.isCancelled else {
                    return
                }
                if let match {
                    SystemPresenter.openInApp(match.songLinkURL)
                } else {
                    // itunes doesn't have it, so there's no page
                    SystemPresenter.alert(title: "Can't Find This Track")
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                SystemPresenter.alert(title: "Couldn't Look Up This Track", message: error.localizedDescription)
            }
            // cleared so sharing the same song again still works
            track.wrappedValue = nil
        }
    }
}
