import AVFoundation
import Synchronization

// passes audio from the real-time thread to captions without locking, mixed down to mono
nonisolated final class AudioRingBuffer: @unchecked Sendable {
    let capacity: Int
    private let samples: UnsafeMutablePointer<Float>
    // running totals; the slot is the total modulo capacity
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

    // called on the real-time thread; if the reader is a whole buffer behind, new audio is dropped
    func write(_ buffers: UnsafeMutableAudioBufferListPointer, frames: Int, channels: Int, interleaved: Bool) {
        guard channels > 0 else {
            return
        }
        let start = written.load(ordering: .relaxed)
        let free = capacity - (start - read.load(ordering: .acquiring))
        let count = min(frames, free)
        guard count > 0 else {
            return
        }

        // averaging the channels makes mono
        let scale = 1 / Float(channels)
        if interleaved {
            // all channels in one buffer: L R L R ...
            guard let data = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return
            }
            for frame in 0..<count {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += data[frame * channels + channel]
                }
                samples[(start + frame) % capacity] = sum * scale
            }
        } else {
            // one buffer per channel
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

    // copies out up to maxCount samples and returns how many
    func read(into destination: UnsafeMutablePointer<Float>, maxCount: Int) -> Int {
        let start = read.load(ordering: .relaxed)
        let count = min(maxCount, written.load(ordering: .acquiring) - start)
        guard count > 0 else {
            return 0
        }
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
