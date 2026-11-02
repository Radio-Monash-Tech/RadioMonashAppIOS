import Foundation

// audio set-up at launch, and reacting to calls and unplugged headphones
extension RadioPlayerModel {
    // runs once per launch, even if the root view's task runs again
    func prepareSession() {
        guard !isSessionPrepared else {
            return
        }
        isSessionPrepared = true
        configureAudioSession()
        audioSession.observe()
        // lock screen buttons
        systemPlayers.configure(
            play: { [weak self] in
                self?.play()
            },
            pause: { [weak self] in
                self?.stop()
            },
            toggle: { [weak self] in
                self?.togglePlayback()
            }
        )
        startMetadataPolling()

        let resumeOnLaunch = UserDefaults.standard.object(forKey: Self.resumeOnLaunchKey) as? Bool ?? false
        if resumeOnLaunch, state == .idle {
            play()
        }
    }

    func configureAudioSession() {
        Task {
            do {
                try await audioSession.configure()
            } catch {
                stream.fail("Couldn't start audio session.")
            }
        }
    }

    func handle(_ event: RadioAudioSession.Event) {
        switch event {
        case .interruptionBegan:
            // a call or alarm started
            guard isActive else {
                return
            }
            resumeAfterInterruption = true
            stop()
        case .interruptionEnded(let shouldResume):
            guard resumeAfterInterruption else {
                return
            }
            resumeAfterInterruption = false
            if shouldResume {
                play()
            }
        case .outputLost:
            // headphones unplugged; stop like ios does instead of playing silence
            if state == .playing {
                stop()
            }
        case .mediaServicesReset:
            // ios restarted its audio, so set up again
            let wasActive = isActive
            configureAudioSession()
            if wasActive {
                play()
            }
        }
    }
}
