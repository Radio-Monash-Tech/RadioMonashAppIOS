import AVFoundation
import MediaToolbox
import Synchronization

// copies the stream's audio for captions without changing how it plays; only works if added before playback
@MainActor
final class AudioTapBridge {
    private weak var item: AVPlayerItem?
    private var context: TapContext?
    private var drainTask: Task<Void, Never>?

    // adds the idle tap; call before the item starts playing
    func install(on item: AVPlayerItem) {
        stopCapture()
        guard item !== self.item else {
            return
        }
        let audioTrack = item.tracks.compactMap(\.assetTrack).first { track in
            track.mediaType == .audio
        }
        guard let track = audioTrack else {
            return
        }

        let context = TapContext()
        guard let tap = Self.makeTap(context: context) else {
            return
        }
        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
        self.item = item
        self.context = context
    }

    // whether this item has the tap, so captions can run on it
    func isInstalled(on item: AVPlayerItem) -> Bool {
        self.item === item && context != nil
    }

    // starts copying audio out; the stream ends on stopCapture()
    func startCapture() -> AsyncStream<AVAudioPCMBuffer>? {
        stopCapture()
        guard let context else {
            return nil
        }
        context.isCapturing.store(true, ordering: .releasing)
        // keeps only the newest few seconds if captions fall behind
        let (stream, continuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self, bufferingPolicy: .bufferingNewest(50))
        drainTask = Task.detached(priority: .userInitiated) {
            await Self.drain(context, into: continuation)
        }
        return stream
    }

    func stopCapture() {
        context?.isCapturing.store(false, ordering: .releasing)
        drainTask?.cancel()
        drainTask = nil
    }

    private static func makeTap(context: TapContext) -> MTAudioProcessingTap? {
        // retained here, released by the tap's finalize callback
        let clientInfo = Unmanaged.passRetained(context).toOpaque()
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientInfo,
            init: tapInit,
            finalize: tapFinalize,
            prepare: tapPrepare,
            unprepare: nil,
            process: tapProcess
        )
        var tap: MTAudioProcessingTap?
        // pre-effects: before volume and mute, so captions work with the sound down
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
        guard status == noErr, let tap else {
            Unmanaged<TapContext>.fromOpaque(clientInfo).release()
            return nil
        }
        return tap
    }

    // moves audio out of the ring buffer every 100 ms, off the main thread
    private nonisolated static func drain(_ context: TapContext, into continuation: AsyncStream<AVAudioPCMBuffer>.Continuation) async {
        defer {
            continuation.finish()
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            guard let format = context.format else {
                continue
            }
            while context.ring.availableToRead > 0 {
                let count = AVAudioFrameCount(min(context.ring.availableToRead, 16_384))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
                      let channel = buffer.floatChannelData?[0]
                else {
                    break
                }
                buffer.frameLength = AVAudioFrameCount(context.ring.read(into: channel, maxCount: Int(count)))
                continuation.yield(buffer)
            }
        }
    }
}

// shared between the tap's c callbacks and the drain task
nonisolated final class TapContext: @unchecked Sendable {
    // about 10 seconds of 48 khz audio
    let ring = AudioRingBuffer(capacity: 480_000)
    // off while captions aren't running, so the idle tap copies nothing
    let isCapturing = Atomic<Bool>(false)
    private let sampleRateBits = Atomic<UInt64>(0)
    // set in prepare, which always runs before the first process call
    var channels = 0
    var isInterleaved = false
    var isFloat = false

    // stored as bits so it can be atomic
    var sampleRate: Double {
        get {
            Double(bitPattern: sampleRateBits.load(ordering: .acquiring))
        }
        set {
            sampleRateBits.store(newValue.bitPattern, ordering: .releasing)
        }
    }

    // mono float at the stream's rate, once the tap knows it
    var format: AVAudioFormat? {
        let rate = sampleRate
        guard rate > 0 else {
            return nil
        }
        return AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
    }

    static func from(_ tap: MTAudioProcessingTap) -> TapContext {
        Unmanaged<TapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    }
}

// the tap callbacks are c function pointers, so they're free functions

private nonisolated func tapInit(
    _ tap: MTAudioProcessingTap,
    _ clientInfo: UnsafeMutableRawPointer?,
    _ storageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    storageOut.pointee = clientInfo
}

private nonisolated func tapFinalize(_ tap: MTAudioProcessingTap) {
    Unmanaged<TapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

// learns the audio format before any audio arrives
private nonisolated func tapPrepare(
    _ tap: MTAudioProcessingTap,
    _ maxFrames: CMItemCount,
    _ format: UnsafePointer<AudioStreamBasicDescription>
) {
    let context = TapContext.from(tap)
    let description = format.pointee
    context.isFloat = description.mFormatID == kAudioFormatLinearPCM
        && description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        && description.mBitsPerChannel == 32
    context.isInterleaved = description.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
    context.channels = Int(description.mChannelsPerFrame)
    context.sampleRate = description.mSampleRate
}

// runs on the real-time thread: no allocating, locking or waiting
private nonisolated func tapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferList: UnsafeMutablePointer<AudioBufferList>,
    _ framesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferList, flagsOut, nil, framesOut)
    guard status == noErr else {
        return
    }
    let context = TapContext.from(tap)
    guard context.isFloat, context.isCapturing.load(ordering: .relaxed) else {
        return
    }
    context.ring.write(
        UnsafeMutableAudioBufferListPointer(bufferList),
        frames: Int(framesOut.pointee),
        channels: context.channels,
        interleaved: context.isInterleaved
    )
}
