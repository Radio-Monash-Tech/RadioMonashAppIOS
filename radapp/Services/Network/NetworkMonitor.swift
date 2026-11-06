import Foundation
import Network

// watches whether the device has wi-fi or mobile data
// @MainActor runs this on the main thread
@MainActor
final class NetworkMonitor {
    // assumed connected until the first check says otherwise
    private(set) var isConnected = true
    // only called when the connection actually changes
    var onChange: ((Bool) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "radapp.network-monitor")

    // MARK: - Watching

    // checks straight away, then again whenever the connection changes
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.update(connected)
            }
        }
        monitor.start(queue: queue)
    }

    private func update(_ connected: Bool) {
        // guard exits early if the check fails
        guard connected != isConnected else {
            return
        }
        isConnected = connected
        onChange?(connected)
    }
}
