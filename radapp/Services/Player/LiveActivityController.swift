import ActivityKit
import Foundation

/// Owns the single "now playing" Live Activity. The player hands it the
/// latest state; this decides whether to start, update or end the activity.
@MainActor
final class LiveActivityController {
    typealias State = RadioActivityAttributes.ContentState

    static let enabledKey = "liveActivityEnabled"

    private var activity: Activity<RadioActivityAttributes>?
    private var lastState: State?

    init() {
        // An activity left over from a previous launch has no player behind it.
        for leftover in Activity<RadioActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? false
    }

    /// `nil` ends the activity. A new one is only started when `canStart` is
    /// true, so a paused or connecting stream never spawns one on its own.
    func sync(_ state: State?, canStart: Bool) {
        guard let state, isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            end()
            return
        }

        if let activity, activity.activityState == .active {
            guard state != lastState else { return }
            lastState = state
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else if canStart {
            // Fails when the app is in the background; the next foreground update retries.
            activity = try? Activity.request(
                attributes: RadioActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil)
            )
            lastState = activity == nil ? nil : state
        }
    }

    private func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
