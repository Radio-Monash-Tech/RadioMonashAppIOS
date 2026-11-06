import UIKit

// audio set-up at launch, and reacting to calls, unplugged headphones and lost connections
extension RadioPlayerModel {
    // MARK: - Launch set-up

    // runs once per launch, even if the root view's task runs again
    func prepareSession() {
        // guard exits early if the check fails
        guard !isSessionPrepared else {
            return
        }
        isSessionPrepared = true
        configureAudioSession()
        audioSession.observe()
        network.start()
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

    // MARK: - Audio events

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

    // MARK: - Network

    func networkChanged(isConnected: Bool) {
        if isConnected {
            Task {
                // the first requests after reconnecting can still fail, so give it a second
                try? await Task.sleep(for: .seconds(1))
                // guard exits early if the check fails
                guard network.isConnected else {
                    return
                }
                // fetching song info sets the badge back to live
                restartPolling()
                if resumeWhenOnline {
                    resumeWhenOnline = false
                    // the stream may have already reconnected by itself
                    if state != .playing {
                        play()
                    }
                }
            }
        } else {
            setIfChanged(\.connectivity, .offline)
            // guard exits early if the check fails
            guard isActive else {
                return
            }
            resumeWhenOnline = true
            showOfflineAlert()
        }
    }

    // only while the app is open, not from the lock screen or a widget
    func showOfflineAlert() {
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        SystemPresenter.settingsAlert(
            title: "No Internet Connection",
            message: "Please turn on Wi-Fi or mobile data to listen to Radio Monash."
        )
    }
}
