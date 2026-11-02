import Foundation

// stopping the stream at a chosen time
extension RadioPlayerModel {
    // when the show on air ends, offered as a timer option
    var currentShowEndsAt: Date? {
        schedule?.onAir()?.end
    }

    // stops the stream at date; nil cancels the timer
    func setSleepTimer(endingAt date: Date?) {
        sleepTimerTask?.cancel()
        sleepTimerEndsAt = date
        // guard exits early if the check fails
        guard let date else {
            return
        }
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, date.timeIntervalSinceNow)))
            guard !Task.isCancelled else {
                return
            }
            self?.sleepTimerFired()
        }
    }

    private func sleepTimerFired() {
        sleepTimerEndsAt = nil
        sleepTimerTask = nil
        if isActive {
            stop()
        }
    }
}
