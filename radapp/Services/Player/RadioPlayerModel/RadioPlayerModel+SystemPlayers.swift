import SwiftUI

// keeping the lock screen player and home screen widget up to date
extension RadioPlayerModel {
    // sends everything the lock screen and widget show
    func refreshSystemPlayers() {
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
            isDark: isDarkAppearance
        ))
    }

    // the appearance setting, read straight from settings
    private var appearance: AppearancePreference {
        guard let raw = UserDefaults.standard.string(forKey: AppearancePreference.storageKey),
              let preference = AppearancePreference(rawValue: raw)
        else {
            return .system
        }
        return preference
    }

    // nil means the widget follows the phone
    private var isDarkAppearance: Bool? {
        guard let scheme = appearance.colorScheme else {
            return nil
        }
        return scheme == .dark
    }

    // the followed shows, read straight from settings
    private var followedShows: StoredIDs {
        guard let raw = UserDefaults.standard.string(forKey: StoredIDs.followedShowsKey),
              let followed = StoredIDs(rawValue: raw)
        else {
            return StoredIDs()
        }
        return followed
    }

    // the next three shows today, by the melbourne date
    private var upcomingShows: [RadioWidgetSnapshot.UpcomingShow] {
        let now = Date()
        let followed = followedShows
        let laterToday = (schedule?.shows ?? []).filter { show in
            show.start > now && Calendar.melbourne.isDate(show.start, inSameDayAs: now)
        }
        return laterToday.prefix(3).map { show in
            .init(start: show.start, title: show.series.title, hosts: show.series.hostLine,
                  isFollowed: followed.contains(show.series.id))
        }
    }
}
