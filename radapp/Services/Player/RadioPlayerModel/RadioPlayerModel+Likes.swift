import Foundation

// liking and unliking songs
extension RadioPlayerModel {
    // the song on air
    func toggleLike() {
        guard canLikeCurrentTrack else {
            return
        }
        favourites?.toggle(title: nowPlaying.title, artist: nowPlaying.artist,
                           artworkURL: nowPlaying.artworkURL, showName: liveShow?.name)
        refreshLikeState()
    }

    // a song from the history
    func toggleLike(_ track: PlayedTrack, showName: String?) {
        favourites?.toggle(title: track.title, artist: track.artist,
                           artworkURL: track.artworkURL, showName: showName)
        refreshLikeState()
    }

    func unlike(_ track: FavouriteTrack) {
        favourites?.remove(track)
        refreshLikeState()
    }

    // updates the heart and the widget
    func refreshLikeState() {
        let isLiked = favourites?.contains(title: nowPlaying.title, artist: nowPlaying.artist) ?? false
        setIfChanged(\.isCurrentTrackLiked, isLiked)
        refreshSystemPlayers()
    }
}
