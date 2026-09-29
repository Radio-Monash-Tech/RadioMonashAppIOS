import Foundation
import UserNotifications

/// Schedules a local notification ten minutes before each upcoming episode
/// of a followed show. Only the loaded week is known, so reminders are
/// rebuilt whenever the schedule, the followed list or the setting changes.
enum ShowReminderScheduler {
    static let enabledKey = "showReminders"
    static let leadTime: TimeInterval = 10 * 60

    private static let identifierPrefix = "show-reminder."
    /// iOS keeps at most 64 pending notifications per app.
    private static let maxPending = 60

    static func sync(shows: [ScheduledShow], followed: StoredIDs, isEnabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard isEnabled else { return }
        let upcoming = shows.filter {
            followed.contains($0.series.id) && $0.start.addingTimeInterval(-leadTime) > .now
        }
        guard !upcoming.isEmpty,
              (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        else { return }

        for show in upcoming.prefix(maxPending) {
            let content = UNMutableNotificationContent()
            content.title = "\(show.series.title) starts in 10 minutes"
            content.body = [show.series.hostLine.map { "with \($0)" }, show.timeRange]
                .compactMap(\.self)
                .joined(separator: " · ")
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

/// Lets reminders show as banners while the app is open.
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
