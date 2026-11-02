import Foundation
import UserNotifications

// MARK: - Reminders

// a notification 10 minutes before each episode of a followed show, rebuilt whenever anything changes
enum ShowReminderScheduler {
    static let enabledKey = "showReminders"
    static let leadTime: TimeInterval = 10 * 60

    private static let identifierPrefix = "show-reminder."
    // ios keeps at most 64 waiting notifications per app
    private static let maxPending = 60

    static func sync(shows: [ScheduledShow], followed: StoredIDs, isEnabled: Bool) async {
        // remove every old reminder first
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                identifier.hasPrefix(identifierPrefix)
            }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        // guard exits early if the check fails
        guard isEnabled else {
            return
        }
        // followed episodes whose reminder time hasn't passed
        let upcoming = shows.filter { show in
            followed.contains(show.series.id) && show.start.addingTimeInterval(-leadTime) > .now
        }
        guard !upcoming.isEmpty,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        else {
            return
        }

        for show in upcoming.prefix(maxPending) {
            let content = UNMutableNotificationContent()
            content.title = "\(show.series.title) starts in 10 minutes"
            // "with Alex · 09:00 – 10:00"
            var parts: [String] = []
            if let hosts = show.series.hostLine {
                parts.append("with \(hosts)")
            }
            parts.append(show.timeRange)
            content.body = parts.joined(separator: " · ")
            content.sound = .default
            content.threadIdentifier = "show-reminders"

            let fireIn = show.start.addingTimeInterval(-leadTime).timeIntervalSinceNow
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: identifierPrefix + show.id, content: content, trigger: trigger
            ))
        }
    }
}

// MARK: - Foreground banners

// lets reminders show as banners while the app is open
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    // nonisolated means not tied to the main thread
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
