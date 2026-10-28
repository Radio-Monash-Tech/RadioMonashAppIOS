import Foundation

// Audio session set-up at launch, and reacting to calls, unplugged
// headphones and other audio system events.
extension RadioPlayerModel {
    /// Runs once per launch; the root view's `.task` can fire again if it reappears.
    func prepareSession() {
        guard !isSessionPrepared else { return }
        isSessionPrepared = true
        configureAudioSession()
        audioSession.observe()
        systemPlayers.configure(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.stop() },
            toggle: { [weak self] in self?.togglePlayback() }
        )
        startMetadataPolling()

        let resumeOnLaunch = UserDefaults.standard.object(forKey: Self.resumeOnLaunchKey) as? Bool ?? false
        if resumeOnLaunch, state == .idle { play() }
    }

    func configureAudioSession() {
        do {
            try audioSession.configure()
        } catch {
            stream.fail("Couldn't start audio session.")
        }
    }

    func handle(_ event: RadioAudioSession.Event) {
        switch event {
        case .interruptionBegan:
            guard isActive else { return }
            resumeAfterInterruption = true
            stop()
        case .interruptionEnded(let shouldResume):
            guard resumeAfterInterruption else { return }
            resumeAfterInterruption = false
            if shouldResume { play() }
        case .outputLost:
            // Match iOS pausing us rather than claim to be playing in silence.
            if state == .playing { stop() }
        case .mediaServicesReset:
            let wasActive = isActive
            configureAudioSession()
            if wasActive { play() }
        }
    }
}
