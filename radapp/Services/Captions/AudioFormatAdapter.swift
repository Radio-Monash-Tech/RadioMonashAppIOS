import AVFoundation

// converts the tapped audio (mono, 44.1 khz) into the format speech recognition wants, usually 16 khz
// nonisolated means not tied to the main thread
nonisolated final class AudioFormatAdapter {
    // the format speech recognition asked for
    let outputFormat: AVAudioFormat
    // kept between chunks so the sound joins up smoothly
    private var converter: AVAudioConverter?

    // made once per caption run
    // init sets up a new instance
    init(outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
    }

    // returns the chunk in the output format, or nil if it fails
    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // already the right format
        if buffer.format == outputFormat {
            return buffer
        }
        // a new converter only when the input format changes
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: outputFormat)
        }
        // guard exits early if the check fails
        guard let converter else {
            return nil
        }

        // room for the resampled audio, plus a little spare
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        // hand over the buffer once, then say "no data for now" so the converter keeps its state
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, output.frameLength > 0 else {
            return nil
        }
        return output
    }
}
