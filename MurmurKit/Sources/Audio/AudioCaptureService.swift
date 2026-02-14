import AVFoundation

/// Actor that captures microphone audio via AVAudioEngine,
/// resamples to 16kHz mono, and emits AudioChunk + AudioLevel streams.
public actor AudioCaptureService {
    private let engine = AVAudioEngine()
    private let vad = VadProcessor()
    private var isRunning = false
    private var sessionStartTime: UInt64 = 0

    private var chunkContinuation: AsyncStream<AudioChunk>.Continuation?
    private var levelContinuation: AsyncStream<AudioLevel>.Continuation?

    /// Stream of resampled audio chunks (16kHz mono Int16).
    public private(set) var chunks: AsyncStream<AudioChunk>!

    /// Stream of audio levels for UI visualization.
    public private(set) var levels: AsyncStream<AudioLevel>!

    public init() {}

    /// Start capturing audio from the default input device.
    public func start() throws {
        guard !isRunning else { return }

        // Create fresh streams for this session
        var chunkCont: AsyncStream<AudioChunk>.Continuation!
        chunks = AsyncStream { chunkCont = $0 }
        chunkContinuation = chunkCont

        var levelCont: AsyncStream<AudioLevel>.Continuation!
        levels = AsyncStream { levelCont = $0 }
        levelContinuation = levelCont

        sessionStartTime = currentTimeMs()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let startTime = sessionStartTime
        let vad = self.vad

        // Use nonisolated sendable closures to bridge the real-time audio thread.
        // Continuations are captured directly (they are Sendable structs).
        let chunkYield = chunkCont!
        let levelYield = levelCont!

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            guard let samples = AudioResampler.resample(buffer) else { return }
            let now = UInt64(Date().timeIntervalSince1970 * 1000)
            let timestampMs = now - startTime

            let chunk = AudioChunk(data: samples, timestampMs: timestampMs)
            chunkYield.yield(chunk)

            let level = vad.process(samples: samples, timestampMs: timestampMs)
            levelYield.yield(level)
        }

        try engine.start()
        isRunning = true
    }

    /// Stop capturing audio and finish streams.
    public func stop() {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false

        chunkContinuation?.finish()
        levelContinuation?.finish()
        chunkContinuation = nil
        levelContinuation = nil
    }

    private nonisolated func currentTimeMs() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }
}
