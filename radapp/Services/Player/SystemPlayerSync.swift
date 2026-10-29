import UIKit
import WidgetKit

/// Keeps the system Now Playing player (Lock Screen and Control Centre) and
/// the Home Screen widget in step with the app, cover art included.
@MainActor
final class SystemPlayerSync {
    struct Snapshot {
        var state: StreamState = .idle
        var title = ""
        var artist: String?
        var show: String?
        var isLiked = false
        var startedAt: Date?
        var duration: TimeInterval?
        /// From the schedule, for the Home Screen widget.
        var showHosts: String?
        var showStart: Date?
        var showEnd: Date?
        var upNext: [RadioWidgetSnapshot.UpcomingShow] = []
        /// The app's Appearance setting; `nil` follows iOS.
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

    /// Fetches the cover for both players. `nil` (unknown tracks, live shows
    /// and tracks without a cover) falls back to the station logo.
    func setArtwork(_ url: URL?) {
        artworkTask?.cancel()
        guard let url else {
            artworkFileName = nil
            artworkImage = nil
            push()
            return
        }
        artworkTask = Task { [weak self] in
            guard let self else { return }
            async let name = widgetArtwork.save(url)
            async let image = ArtworkCache.shared.load(url)
            let (savedName, loadedImage) = await (name, image)
            guard !Task.isCancelled else { return }
            artworkFileName = savedName
            artworkImage = loadedImage
            push()
        }
    }

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
        // Reloads are budgeted, so only ask when something actually changed.
        if widget.save() {
            WidgetCenter.shared.reloadTimelines(ofKind: RadioWidgetSnapshot.widgetKind)
        }
    }
}
