import AVFoundation
import Combine
import UIKit

// the connection to the station's audio; rides out buffering and reconnects when it drops
@MainActor
final class RadioStream {
    private(set) var state: StreamState = .idle {
        didSet {
            onStateChange?(state)
        }
    }
    var onStateChange: ((StreamState) -> Void)?
    // a new connection is about to play; captions attach here, before playback starts
    var onItemReady: ((AVPlayerItem) -> Void)?
    // mute is volume 0, since a muted player gives the captions silence
    var isMuted = false {
        didSet {
            applyVolume()
        }
    }
    var volume: Float = 1 {
        didSet {
            applyVolume()
        }
    }

    // the station's radiocult stream
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

    // always a fresh connection; a paused live stream goes stale and plays silence
    func play() {
        reconnectAttempts = 0
        start()
    }

    // pausing drops the connection; play() rejoins live
    func stop() {
        tearDown()
        state = .paused
    }

    // a failure from outside, like the audio session
    func fail(_ message: String) {
        tearDown()
        state = .failed(message)
    }

    // connects and watches for ready, stalls and drops
    private func start() {
        tearDown()
        state = .connecting
        // the session can switch off while the app was suspended
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.volume = isMuted ? 0 : volume
        player.automaticallyWaitsToMinimizeStalling = true
        self.player = player

        // ready to play, or failed
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                guard let self, self.player?.currentItem === item else {
                    return
                }
                switch status {
                case .readyToPlay:
                    guard self.state == .connecting else {
                        return
                    }
                    self.onItemReady?(item)
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

        // playing or buffering
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self, self.player === player else {
                    return
                }
                self.timeControlStatusChanged(status)
            }
        }

        // the server closing the connection "ends" live radio, so both mean reconnect
        let center = NotificationCenter.default
        for name in [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification] {
            center.publisher(for: name, object: item)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.player?.currentItem === item else {
                            return
                        }
                        self.streamDropped()
                    }
                }
                .store(in: &subscriptions)
        }
    }

    private func applyVolume() {
        player?.volume = isMuted ? 0 : volume
    }

    // stops everything and forgets the old connection
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
            // short buffering sorts itself out; stuck for 12 seconds means the connection is gone
            guard stallWatchdog == nil else {
                return
            }
            stallWatchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.stallTimeout))
                guard !Task.isCancelled, let self else {
                    return
                }
                self.stallWatchdog = nil
                if self.player?.timeControlStatus != .playing {
                    self.streamDropped()
                }
            }
        default:
            break
        }
    }

    // reconnects with longer waits each time, failing only once every attempt has failed
    private func streamDropped() {
        guard state == .playing || state == .connecting else {
            return
        }
        // only a stream that was already playing retries; a first connection fails straight away
        let isRecovering = state == .playing || reconnectAttempts > 0
        guard isRecovering, reconnectAttempts < Self.maxReconnectAttempts else {
            if isRecovering {
                fail("Lost connection to the stream.")
            } else {
                fail("We couldn't reach the stream.")
            }
            return
        }
        reconnectAttempts += 1
        // 1, 2, 4, 8, 16, 16 seconds
        let delay = min(16, pow(2, Double(reconnectAttempts - 1)))

        tearDown()
        state = .connecting
        // ask ios for time, or it suspends a silent app in the background
        beginReconnectBackgroundTask()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.state == .connecting else {
                return
            }
            self.start()
            // start() ended the old background task, so begin another until it's ready
            self.beginReconnectBackgroundTask()
        }
    }

    private func beginReconnectBackgroundTask() {
        reconnectBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endReconnectBackgroundTask()
        }
    }

    private func endReconnectBackgroundTask() {
        guard reconnectBackgroundTask != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(reconnectBackgroundTask)
        reconnectBackgroundTask = .invalid
    }
}
