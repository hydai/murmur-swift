import AVFoundation
import Speech

/// On-device STT using Apple's SpeechTranscriber (macOS 26+ / iOS 26+).
///
/// This replaces ~200 lines of Rust<->Swift FFI bridge code with direct
/// framework calls. SpeechTranscriber with progressiveTranscription preset
/// provides streaming partial + committed results.
public actor AppleSttProvider: SttProvider {
    private let locale: Locale
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var resultTask: Task<Void, Never>?
    private var audioContinuation: AsyncStream<AnalyzerInput>.Continuation?

    /// Cumulative sample count for monotonic timeline.
    private var cumulativeSampleCount: Int64 = 0

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    /// Create a provider for the given locale (pass nil for system default).
    public init(locale: Locale? = nil) {
        self.locale = locale ?? Locale.current

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        guard let transcriber else {
            throw MurmurError.stt("Failed to create SpeechTranscriber")
        }

        // Create audio input stream for feeding buffers
        var audioCont: AsyncStream<AnalyzerInput>.Continuation!
        let audioStream = AsyncStream<AnalyzerInput> { audioCont = $0 }
        audioContinuation = audioCont

        analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let analyzer else {
            throw MurmurError.stt("Failed to create SpeechAnalyzer")
        }

        cumulativeSampleCount = 0

        // Start analyzer processing in a separate task
        let analyzeTask = Task {
            try await analyzer.start(inputSequence: audioStream)
        }

        // Iterate transcription results
        resultTask = Task { [weak self] in
            _ = analyzeTask
            do {
                for try await result in transcriber.results {
                    guard let self else { break }
                    let text = String(result.text.characters)
                    guard !text.isEmpty else { continue }

                    let timestampMs = UInt64(max(0, result.range.start.seconds * 1000))

                    if result.isFinal {
                        await self.emit(.committed(text: text, timestampMs: timestampMs))
                    } else {
                        await self.emit(.partial(text: text, timestampMs: timestampMs))
                    }
                }
            } catch {
                guard let self else { return }
                await self.emit(.error(message: error.localizedDescription))
            }
        }
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        guard let audioContinuation else {
            throw MurmurError.stt("Session not started")
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        )!

        let frameCount = AVAudioFrameCount(chunk.data.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MurmurError.stt("Failed to create audio buffer")
        }
        buffer.frameLength = frameCount

        chunk.data.withUnsafeBufferPointer { src in
            buffer.int16ChannelData![0].update(from: src.baseAddress!, count: chunk.data.count)
        }

        // Build monotonic timeline
        let startTimeNs = cumulativeSampleCount * 1_000_000_000 / 16000
        cumulativeSampleCount += Int64(chunk.data.count)

        let bufferStartTime = CMTime(value: startTimeNs, timescale: 1_000_000_000)
        let input = AnalyzerInput(buffer: buffer, bufferStartTime: bufferStartTime)
        audioContinuation.yield(input)
    }

    public func stopSession() async throws {
        audioContinuation?.finish()
        audioContinuation = nil

        // Wait for results to drain
        await resultTask?.value
        resultTask = nil
        transcriber = nil
        analyzer = nil

        eventContinuation.finish()
    }

    private func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }
}
