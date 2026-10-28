import Foundation

// Stopping the stream at a chosen time.
extension RadioPlayerModel {
    /// When the on-air show ends, if the schedule knows it; offered as a sleep timer option.
    var currentShowEndsAt: Date? {
        schedule?.onAir()?.end
    }

    /// Stops the stream at `date`. Passing `nil` cancels the timer.
    func setSleepTimer(endingAt date: Date?) {
        sleepTimerTask?.cancel()
        sleepTimerEndsAt = date
        guard let date else { return }
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.sleepTimerFired()
        }
    }

    private func sleepTimerFired() {
        sleepTimerEndsAt = nil
        sleepTimerTask = nil
        if isActive { stop() }
    }
}
