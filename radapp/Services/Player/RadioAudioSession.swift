import AVFoundation
import Combine

// the phone's audio set up for radio, and the system events the player reacts to
// @MainActor runs this on the main thread
@MainActor
final class RadioAudioSession {
    // MARK: - Events

    enum Event {
        // a call or alarm took the audio
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        // headphones were unplugged
        case outputLost
        // ios restarted its audio system
        case mediaServicesReset
    }

    var onEvent: ((Event) -> Void)?
    private var subscriptions = Set<AnyCancellable>()

    // MARK: - Setup

    // playback keeps playing when locked, ignores the silent switch and gets the lock screen controls
    func configure() async throws {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try await Self.activate()
    }

    // switching the session on can block, so it runs off the main thread
    // @concurrent runs this async function off the caller's thread
    @concurrent
    // nonisolated means not tied to the main thread
    nonisolated static func activate() async throws {
        try AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - System notifications

    func observe() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        // calls and alarms
        center.publisher(for: AVAudioSession.interruptionNotification, object: session)
            .sink { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let type = rawType.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
                Task { @MainActor in
                    switch type {
                    case .began:
                        self?.onEvent?(.interruptionBegan)
                    case .ended:
                        self?.onEvent?(.interruptionEnded(shouldResume: shouldResume))
                    default:
                        break
                    }
                }
            }
            .store(in: &subscriptions)

        // headphones or bluetooth disconnected
        center.publisher(for: AVAudioSession.routeChangeNotification, object: session)
            .sink { [weak self] note in
                let rawReason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                let reason = rawReason.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                // guard exits early if the check fails
                guard reason == .oldDeviceUnavailable else {
                    return
                }
                Task { @MainActor in
                    self?.onEvent?(.outputLost)
                }
            }
            .store(in: &subscriptions)

        center.publisher(for: AVAudioSession.mediaServicesWereResetNotification, object: session)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.onEvent?(.mediaServicesReset)
                }
            }
            .store(in: &subscriptions)
    }
}
