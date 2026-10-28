import SwiftUI

// Keeping the Live Activity, Lock Screen player and Home Screen widget up to date.
extension RadioPlayerModel {
    /// Pushes the current state to the Lock Screen Live Activity, the system
    /// player and the Home Screen widget. Also called by Settings when the Live
    /// Activity toggle changes, and when the schedule or followed shows change.
    func refreshLiveActivity() {
        let onAir = scheduledLiveShow
        systemPlayers.update(.init(
            state: state,
            title: displayTitle,
            artist: displayArtist,
            show: liveShow?.name,
            isLiked: isCurrentTrackLiked,
            startedAt: nowPlaying.startedAt,
            duration: nowPlaying.duration,
            showHosts: onAir?.series.hostLine,
            showStart: onAir?.start,
            showEnd: onAir?.end,
            upNext: upcomingShows,
            isDark: appearance.colorScheme.map { $0 == .dark }
        ))
    }

    private var appearance: AppearancePreference {
        UserDefaults.standard.string(forKey: AppearancePreference.storageKey)
            .flatMap(AppearancePreference.init(rawValue:)) ?? .system
    }

    /// The rest of today's shows, by the station's Melbourne date.
    private var upcomingShows: [RadioWidgetSnapshot.UpcomingShow] {
        let now = Date()
        let followed = UserDefaults.standard.string(forKey: StoredIDs.followedShowsKey)
            .flatMap(StoredIDs.init(rawValue:)) ?? StoredIDs()
        return (schedule?.shows ?? [])
            .filter { $0.start > now && Calendar.melbourne.isDate($0.start, inSameDayAs: now) }
            .prefix(3)
            .map { show in
                .init(start: show.start, title: show.series.title, hosts: show.series.hostLine,
                      isFollowed: followed.contains(show.series.id))
            }
    }
}
