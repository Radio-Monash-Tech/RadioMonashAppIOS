import AVFoundation
import Combine

/// The shared audio session, set up for radio, and the system events the
/// player has to react to.
@MainActor
final class RadioAudioSession {
    enum Event {
        /// A phone call or alarm took the audio; iOS has already paused us.
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        /// Headphones were unplugged; iOS has already paused us.
        case outputLost
        case mediaServicesReset
    }

    var onEvent: ((Event) -> Void)?
    private var subscriptions = Set<AnyCancellable>()

    func configure() throws {
        let session = AVAudioSession.sharedInstance()
        // .playback keeps audio alive when the screen locks and ignores
        // the silent switch the way a radio should. Not mixing with other
        // audio makes us the Now Playing app, which gets the Lock Screen
        // and Control Centre controls.
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    func observe() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        center.publisher(for: AVAudioSession.interruptionNotification, object: session)
            .sink { [weak self] note in
                let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                let options = AVAudioSession.InterruptionOptions(
                    rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                let shouldResume = options.contains(.shouldResume)
                Task { @MainActor in
                    switch type {
                    case .began: self?.onEvent?(.interruptionBegan)
                    case .ended: self?.onEvent?(.interruptionEnded(shouldResume: shouldResume))
                    default: break
                    }
                }
            }
            .store(in: &subscriptions)

        center.publisher(for: AVAudioSession.routeChangeNotification, object: session)
            .sink { [weak self] note in
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                    .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                guard reason == .oldDeviceUnavailable else { return }
                Task { @MainActor in self?.onEvent?(.outputLost) }
            }
            .store(in: &subscriptions)

        center.publisher(for: AVAudioSession.mediaServicesWereResetNotification, object: session)
            .sink { [weak self] _ in
                Task { @MainActor in self?.onEvent?(.mediaServicesReset) }
            }
            .store(in: &subscriptions)
    }
}
