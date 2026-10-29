import AVFoundation
import MediaToolbox
import Synchronization

/// Taps the decoded audio of the playing stream without changing how it
/// plays. An `MTAudioProcessingTap` on the player item copies each render
/// cycle into a ring buffer; a background task drains it every 100 ms and
/// publishes mono buffers as an `AsyncStream`.
///
/// This works because the RadioCult stream is a plain Icecast MP3 stream.
/// AVPlayer doesn't allow taps on HLS. The tap only takes effect if it's in
/// place before playback starts, so it's installed on every new connection
/// and sits idle until captions start capturing.
@MainActor
final class AudioTapBridge {
    private weak var item: AVPlayerItem?
    private var context: TapContext?
    private var drainTask: Task<Void, Never>?

    /// Installs the (idle) tap. Call before the item starts playing.
    func install(on item: AVPlayerItem) {
        stopCapture()
        guard item !== self.item,
              let track = item.tracks.compactMap(\.assetTrack).first(where: { $0.mediaType == .audio })
        else { return }

        let context = TapContext()
        guard let tap = Self.makeTap(context: context) else { return }
        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        item.audioMix = mix
        self.item = item
        self.context = context
    }

    /// Whether `item` has the tap, so captions can run on it.
    func isInstalled(on item: AVPlayerItem) -> Bool {
        self.item === item && context != nil
    }

    /// Starts copying audio out. The stream finishes on `stopCapture()`.
    func startCapture() -> AsyncStream<AVAudioPCMBuffer>? {
        stopCapture()
        guard let context else { return nil }
        context.isCapturing.store(true, ordering: .releasing)
        // Keep only the newest few seconds if the pipeline ever falls behind.
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
        // Retained here, released by the tap's finalize callback.
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
        // Pre-effects: the audio before the player's volume and mute, so
        // captions keep working with the sound turned down.
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap)
        guard status == noErr, let tap else {
            Unmanaged<TapContext>.fromOpaque(clientInfo).release()
            return nil
        }
        return tap
    }

    /// Moves audio out of the ring buffer in 100 ms steps, off the main thread.
    private nonisolated static func drain(_ context: TapContext, into continuation: AsyncStream<AVAudioPCMBuffer>.Continuation) async {
        defer { continuation.finish() }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            guard let format = context.format else { continue }
            while context.ring.availableToRead > 0 {
                let count = AVAudioFrameCount(min(context.ring.availableToRead, 16_384))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
                      let channel = buffer.floatChannelData?[0]
                else { break }
                buffer.frameLength = AVAudioFrameCount(context.ring.read(into: channel, maxCount: Int(count)))
                continuation.yield(buffer)
            }
        }
    }
}

/// Shared between the tap's C callbacks and the drain task.
nonisolated final class TapContext: @unchecked Sendable {
    /// About 10 seconds of 48 kHz audio.
    let ring = AudioRingBuffer(capacity: 480_000)
    /// Off while captions aren't running, so the idle tap copies nothing.
    let isCapturing = Atomic<Bool>(false)
    private let sampleRateBits = Atomic<UInt64>(0)
    // Set in prepare, which always runs before the first process call.
    var channels = 0
    var isInterleaved = false
    var isFloat = false

    var sampleRate: Double {
        get { Double(bitPattern: sampleRateBits.load(ordering: .acquiring)) }
        set { sampleRateBits.store(newValue.bitPattern, ordering: .releasing) }
    }

    /// Mono float at the stream's rate, once the tap knows it.
    var format: AVAudioFormat? {
        let rate = sampleRate
        return rate > 0 ? AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) : nil
    }

    static func from(_ tap: MTAudioProcessingTap) -> TapContext {
        Unmanaged<TapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    }
}

// MARK: - Tap callbacks (C function pointers, so free functions)

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

/// Runs on the real-time render thread: no allocating, locking or awaiting.
private nonisolated func tapProcess(
    _ tap: MTAudioProcessingTap,
    _ numberFrames: CMItemCount,
    _ flags: MTAudioProcessingTapFlags,
    _ bufferList: UnsafeMutablePointer<AudioBufferList>,
    _ framesOut: UnsafeMutablePointer<CMItemCount>,
    _ flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    guard MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferList, flagsOut, nil, framesOut) == noErr else { return }
    let context = TapContext.from(tap)
    guard context.isFloat, context.isCapturing.load(ordering: .relaxed) else { return }
    context.ring.write(
        UnsafeMutableAudioBufferListPointer(bufferList),
        frames: Int(framesOut.pointee),
        channels: context.channels,
        interleaved: context.isInterleaved
    )
}
