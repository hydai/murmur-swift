@preconcurrency import AVFoundation

/// Resamples audio to 16kHz mono Int16 format using AVAudioConverter.
public final class AudioResampler: Sendable {
    /// Target format: 16kHz, mono, Int16.
    public static let targetSampleRate: Double = 16000
    public static let targetChannels: AVAudioChannelCount = 1

    public static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: targetSampleRate,
        channels: targetChannels,
        interleaved: true
    )!

    /// Convert an AVAudioPCMBuffer (any format) to 16kHz mono Int16 samples.
    ///
    /// Returns nil if conversion fails.
    public static func resample(_ buffer: AVAudioPCMBuffer) -> [Int16]? {
        let sourceFormat = buffer.format

        // If already in target format, extract directly
        if sourceFormat.sampleRate == targetSampleRate
            && sourceFormat.channelCount == targetChannels
            && sourceFormat.commonFormat == .pcmFormatInt16
        {
            return extractInt16Samples(from: buffer)
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }

        let ratio = targetSampleRate / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else {
            return nil
        }

        var error: NSError?
        nonisolated(unsafe) var hasData = true
        nonisolated(unsafe) let inputBuffer = buffer
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return inputBuffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if error != nil { return nil }
        return extractInt16Samples(from: outputBuffer)
    }

    private static func extractInt16Samples(from buffer: AVAudioPCMBuffer) -> [Int16]? {
        guard let int16Data = buffer.int16ChannelData else { return nil }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: int16Data[0], count: count))
    }
}
