import Foundation

// play and pause
extension RadioPlayerModel {
    func togglePlayback() {
        switch state {
        case .playing:
            stop()
        case .paused, .idle, .failed:
            play()
        case .connecting:
            // already on its way
            break
        }
    }

    // still tries to connect when offline, the alert just explains why it may not
    func play() {
        if !network.isConnected {
            showOfflineAlert()
            // this attempt will fail, so try again when the connection's back
            resumeWhenOnline = true
        }
        stream.play()
    }

    func stop() {
        // pausing while offline means don't start again when the connection's back
        resumeWhenOnline = false
        stream.stop()
    }
}
