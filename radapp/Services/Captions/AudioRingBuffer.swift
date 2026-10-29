import AVFoundation
import Synchronization

/// Hands audio from the real-time render thread to the caption pipeline.
/// One thread writes and one reads; neither ever locks or allocates, so the
/// render thread can't stall and glitch the stream. Audio is mixed to mono
/// on the way in, since captions don't need stereo.
nonisolated final class AudioRingBuffer: @unchecked Sendable {
    let capacity: Int
    private let samples: UnsafeMutablePointer<Float>
    // Running totals; the slot is the total modulo capacity.
    private let written = Atomic<Int>(0)
    private let read = Atomic<Int>(0)

    init(capacity: Int) {
        self.capacity = capacity
        samples = .allocate(capacity: capacity)
        samples.initialize(repeating: 0, count: capacity)
    }

    deinit {
        samples.deallocate()
    }

    /// Called on the render thread with 32-bit float audio. If the reader has
    /// fallen a whole buffer behind, the newest audio is dropped rather than
    /// overwriting what it hasn't read yet.
    func write(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int, channels: Int, interleaved: Bool) {
        guard channels > 0 else { return }
        let start = written.load(ordering: .relaxed)
        let free = capacity - (start - read.load(ordering: .acquiring))
        let count = min(frames, free)
        guard count > 0 else { return }

        let scale = 1 / Float(channels)
        if interleaved {
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return }
            for frame in 0..<count {
                var sum: Float = 0
                for channel in 0..<channels { sum += data[frame * channels + channel] }
                samples[(start + frame) % capacity] = sum * scale
            }
        } else {
            for frame in 0..<count {
                var sum: Float = 0
                for channel in 0..<min(channels, buffers.count) {
                    if let data = buffers[channel].mData?.assumingMemoryBound(to: Float.self) {
                        sum += data[frame]
                    }
                }
                samples[(start + frame) % capacity] = sum * scale
            }
        }
        written.store(start + count, ordering: .releasing)
    }

    /// Copies out up to `maxCount` samples; returns how many it copied.
    func read(into destination: UnsafeMutablePointer<Float>, maxCount: Int) -> Int {
        let start = read.load(ordering: .relaxed)
        let count = min(maxCount, written.load(ordering: .acquiring) - start)
        guard count > 0 else { return 0 }
        for index in 0..<count {
            destination[index] = samples[(start + index) % capacity]
        }
        read.store(start + count, ordering: .releasing)
        return count
    }

    var availableToRead: Int {
        written.load(ordering: .acquiring) - read.load(ordering: .relaxed)
    }
}
