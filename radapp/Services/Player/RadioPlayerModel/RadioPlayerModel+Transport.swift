import Foundation

// Play, pause and retry.
extension RadioPlayerModel {
    func togglePlayback() {
        switch state {
        case .playing:
            stop()
        case .paused, .idle, .failed:
            play()
        case .connecting:
            break
        }
    }

    func play() {
        stream.play()
    }

    func retry() {
        play()
    }

    func stop() {
        stream.stop()
    }
}
