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

    func play() {
        stream.play()
    }

    func stop() {
        stream.stop()
    }
}
