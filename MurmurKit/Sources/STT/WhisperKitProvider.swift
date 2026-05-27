import Foundation

/// Native Argmax WhisperKit STT.
///
/// The open-source SDK path is treated as batch transcription for the first
/// integration: audio is buffered during recording and transcribed when the
/// session stops.
public actor WhisperKitProvider: SttProvider {
    private let config: WhisperKitSttConfig
    private let language: String?
    private let runtimeStore: WhisperKitRuntimeStore
    private let realtimeInterval: Duration
    private let realtimeMinimumSamples: Int

    private var sampleBuffer: [Int16] = []
    private var streamTask: Task<Void, Never>?
    private var isStopping = false
    private var lastRealtimeSampleCount = 0
    private var realtimeState = WhisperKitRealtimeState()

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(
        config: WhisperKitSttConfig = WhisperKitSttConfig(),
        language: String? = nil,
        runtimeStore: WhisperKitRuntimeStore = .shared,
        realtimeInterval: Duration = .milliseconds(1500),
        realtimeMinimumSamples: Int = 16000
    ) {
        self.config = config
        self.language = language
        self.runtimeStore = runtimeStore
        self.realtimeInterval = realtimeInterval
        self.realtimeMinimumSamples = realtimeMinimumSamples

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        sampleBuffer = []
        isStopping = false
        lastRealtimeSampleCount = 0
        realtimeState = WhisperKitRealtimeState()
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.runRealtimeLoop()
        }
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        sampleBuffer.append(contentsOf: chunk.data)
    }

    public func stopSession() async throws {
        defer { eventContinuation.finish() }

        isStopping = true
        streamTask?.cancel()
        streamTask = nil

        guard !sampleBuffer.isEmpty else { return }

        let samples = sampleBuffer
        sampleBuffer = []

        do {
            let segments = try await runtimeStore.transcribeSegments(
                samples: Self.floatSamples(from: samples),
                config: config,
                language: language,
                clipStartSeconds: realtimeState.confirmedEndSeconds,
                onStatus: { _ in }
            )
            for event in realtimeState.finalize(segments) {
                emit(event)
            }
        } catch {
            emit(.error(message: "WhisperKit error: \(error.localizedDescription)"))
        }
    }

    public static func floatSamples(from samples: [Int16]) -> [Float] {
        samples.map { sample in
            max(-1.0, Float(sample) / Float(Int16.max))
        }
    }

    private func runRealtimeLoop() async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: realtimeInterval)
            } catch {
                return
            }

            if Task.isCancelled || isStopping { return }

            let snapshot = realtimeSnapshot()
            guard let snapshot else { continue }

            do {
                let segments = try await runtimeStore.transcribeSegments(
                    samples: Self.floatSamples(from: snapshot.samples),
                    config: config,
                    language: language,
                    clipStartSeconds: snapshot.confirmedEndSeconds,
                    onStatus: { _ in }
                )
                handleRealtimeSegments(segments, sampleCount: snapshot.sampleCount)
            } catch is CancellationError {
                return
            } catch {
                if !isStopping {
                    emit(.error(message: "WhisperKit realtime error: \(error.localizedDescription)"))
                }
                return
            }
        }
    }

    private func realtimeSnapshot() -> RealtimeSnapshot? {
        guard sampleBuffer.count >= realtimeMinimumSamples else { return nil }
        guard sampleBuffer.count > lastRealtimeSampleCount else { return nil }

        return RealtimeSnapshot(
            samples: sampleBuffer,
            sampleCount: sampleBuffer.count,
            confirmedEndSeconds: realtimeState.confirmedEndSeconds
        )
    }

    private func handleRealtimeSegments(
        _ segments: [WhisperKitTranscriptSegment],
        sampleCount: Int
    ) {
        guard !isStopping else { return }
        lastRealtimeSampleCount = sampleCount
        for event in realtimeState.handleHypothesis(segments) {
            emit(event)
        }
    }

    private nonisolated func emit(_ event: TranscriptionEvent) {
        eventContinuation.yield(event)
    }

    private struct RealtimeSnapshot: Sendable {
        var samples: [Int16]
        var sampleCount: Int
        var confirmedEndSeconds: Float
    }
}
