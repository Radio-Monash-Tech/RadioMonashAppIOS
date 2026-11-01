import UIKit
import WidgetKit

// keeps the lock screen player and home screen widget in step with the app
@MainActor
final class SystemPlayerSync {
    // everything both of them show
    struct Snapshot {
        var state: StreamState = .idle
        var title = ""
        var artist: String?
        var show: String?
        var isLiked = false
        var startedAt: Date?
        var duration: TimeInterval?
        // from the schedule, for the widget
        var showHosts: String?
        var showStart: Date?
        var showEnd: Date?
        var upNext: [RadioWidgetSnapshot.UpcomingShow] = []
        // the app's appearance setting; nil follows ios
        var isDark: Bool?
    }

    private let nowPlaying = NowPlayingController()
    private let widgetArtwork = WidgetArtworkStore()
    private var artworkFileName: String?
    private var artworkImage: UIImage?
    private var artworkTask: Task<Void, Never>?
    private var latest = Snapshot()

    func configure(play: @escaping () -> Void, pause: @escaping () -> Void, toggle: @escaping () -> Void) {
        nowPlaying.configure(play: play, pause: pause, toggle: toggle)
    }

    func update(_ snapshot: Snapshot) {
        latest = snapshot
        push()
    }

    // loads the cover for both; nil falls back to the station logo
    func setArtwork(_ url: URL?) {
        artworkTask?.cancel()
        guard let url else {
            artworkFileName = nil
            artworkImage = nil
            push()
            return
        }
        artworkTask = Task { [weak self] in
            guard let self else {
                return
            }
            // save it for the widget and load it for the lock screen at the same time
            async let name = widgetArtwork.save(url)
            async let image = ArtworkCache.shared.load(url)
            let (savedName, loadedImage) = await (name, image)
            guard !Task.isCancelled else {
                return
            }
            artworkFileName = savedName
            artworkImage = loadedImage
            push()
        }
    }

    // sends the latest snapshot to both
    private func push() {
        let snapshot = latest
        pushHomeWidget(snapshot)
        switch snapshot.state {
        case .idle, .failed:
            nowPlaying.clear()
        case .connecting, .playing, .paused:
            let isPlaying = snapshot.state == .playing
            nowPlaying.update(
                title: snapshot.title,
                artist: snapshot.artist,
                show: snapshot.show,
                isPlaying: isPlaying,
                artwork: artworkImage ?? UIImage(named: "StationLogo")
            )
        }
    }

    private func pushHomeWidget(_ snapshot: Snapshot) {
        let widget = RadioWidgetSnapshot(
            isOnAir: snapshot.show != nil,
            isPlaying: snapshot.state == .playing,
            isLiked: snapshot.isLiked,
            title: snapshot.title,
            subtitle: snapshot.artist ?? snapshot.showHosts,
            showName: snapshot.show,
            showStart: snapshot.showStart,
            showEnd: snapshot.showEnd,
            artworkFileName: artworkFileName,
            upNext: snapshot.upNext,
            isDark: snapshot.isDark
        )
        // widget reloads are limited, so only when something changed
        if widget.save() {
            WidgetCenter.shared.reloadTimelines(ofKind: RadioWidgetSnapshot.widgetKind)
        }
    }
}
