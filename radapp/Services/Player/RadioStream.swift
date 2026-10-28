import AVFoundation
import Combine
import UIKit

/// The connection to the station's audio stream. Rides out short buffering,
/// reconnects with backoff when the stream drops mid-listen, and reports
/// every state change through `onStateChange`.
@MainActor
final class RadioStream {
    private(set) var state: StreamState = .idle {
        didSet { onStateChange?(state) }
    }
    var onStateChange: ((StreamState) -> Void)?
    var isMuted = false { didSet { player?.isMuted = isMuted } }
    var volume: Float = 1 { didSet { player?.volume = volume } }

    /// RadioCult stream for the station.
    private let url = URL(string: "https://radio-monash.radiocult.fm/stream")!

    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var subscriptions = Set<AnyCancellable>()
    private var stallWatchdog: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private var reconnectBackgroundTask: UIBackgroundTaskIdentifier = .invalid

    private static let stallTimeout: TimeInterval = 12
    private static let maxReconnectAttempts = 6

    /// Always opens a fresh connection. A live stream that has sat paused goes
    /// stale, and resuming it plays silence instead of the station.
    func play() {
        reconnectAttempts = 0
        start()
    }

    /// Pausing live radio drops the connection; `play()` rejoins it live.
    func stop() {
        tearDown()
        state = .paused
    }

    /// Reports a failure from outside the stream, such as the audio session.
    func fail(_ message: String) {
        tearDown()
        state = .failed(message)
    }

    private func start() {
        tearDown()
        state = .connecting
        // The session can be deactivated while the app sat suspended.
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = isMuted
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    guard self.state == .connecting else { return }
                    self.player?.play()
                    self.endReconnectBackgroundTask()
                    self.state = .playing
                case .failed:
                    self.streamDropped()
                default:
                    break
                }
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self, self.player === player else { return }
                self.timeControlStatusChanged(status)
            }
        }

        // The server closing the connection ends the item even though live
        // radio never really ends, so both notifications mean "reconnect".
        let center = NotificationCenter.default
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            center.publisher(for: name, object: item)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.player?.currentItem === item else { return }
                        self.streamDropped()
                    }
                }
                .store(in: &subscriptions)
        }
    }

    private func tearDown() {
        reconnectTask?.cancel()
        reconnectTask = nil
        stallWatchdog?.cancel()
        stallWatchdog = nil
        statusObservation = nil
        timeControlObservation = nil
        subscriptions.removeAll()
        player?.pause()
        player = nil
        endReconnectBackgroundTask()
    }

    private func timeControlStatusChanged(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            stallWatchdog?.cancel()
            stallWatchdog = nil
            reconnectAttempts = 0
        case .waitingToPlayAtSpecifiedRate where state == .playing:
            // AVPlayer rides out short buffering on its own; a stream that
            // stays stuck has usually lost its connection for good.
            guard stallWatchdog == nil else { return }
            stallWatchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.stallTimeout))
                guard !Task.isCancelled, let self else { return }
                self.stallWatchdog = nil
                if self.player?.timeControlStatus != .playing { self.streamDropped() }
            }
        default:
            break
        }
    }

    /// Reconnects after the stream drops mid-listen, backing off between
    /// attempts, and only reports a failure once every attempt has failed.
    private func streamDropped() {
        guard state == .playing || state == .connecting else { return }
        // A first connection that fails is reported straight away; only a
        // stream that was already playing (or reconnecting) retries.
        let isRecovering = state == .playing || reconnectAttempts > 0
        guard isRecovering, reconnectAttempts < Self.maxReconnectAttempts else {
            fail(isRecovering ? "Lost connection to the stream." : "We couldn't reach the stream.")
            return
        }
        reconnectAttempts += 1
        let delay = min(16, pow(2, Double(reconnectAttempts - 1)))

        tearDown()
        state = .connecting
        // With no audio playing, iOS suspends a backgrounded app within
        // seconds; ask for time so the reconnect still happens.
        beginReconnectBackgroundTask()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.state == .connecting else { return }
            self.start()
            // start() ended the old background task; keep one alive until
            // the new connection is ready.
            self.beginReconnectBackgroundTask()
        }
    }

    private func beginReconnectBackgroundTask() {
        reconnectBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endReconnectBackgroundTask()
        }
    }

    private func endReconnectBackgroundTask() {
        guard reconnectBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(reconnectBackgroundTask)
        reconnectBackgroundTask = .invalid
    }
}
