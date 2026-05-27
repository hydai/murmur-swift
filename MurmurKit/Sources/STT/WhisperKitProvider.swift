import Foundation

public struct WhisperKitRealtimeOptions: Sendable, Equatable {
    public var intervalMilliseconds: Int
    public var minimumSamples: Int
    public var requiredSegmentsForConfirmation: Int

    public init(
        intervalMilliseconds: Int = 1500,
        minimumSamples: Int = 16000,
        requiredSegmentsForConfirmation: Int = 2
    ) {
        self.intervalMilliseconds = max(100, intervalMilliseconds)
        self.minimumSamples = max(1, minimumSamples)
        self.requiredSegmentsForConfirmation = max(0, requiredSegmentsForConfirmation)
    }

    var interval: Duration {
        .milliseconds(intervalMilliseconds)
    }
}

public enum WhisperKitProviderMetric: Sendable, Equatable {
    case sessionStarted(model: String, intervalMs: Int, minimumSamples: Int, requiredSegmentsForConfirmation: Int)
    case audioReceived(totalSamples: Int, chunkSamples: Int, timestampMs: UInt64)
    case realtimePassStarted(sampleCount: Int, confirmedEndSeconds: Float)
    case realtimePassFinished(sampleCount: Int, segmentCount: Int, emittedEventCount: Int, durationMs: UInt64)
    case realtimePassFailed(sampleCount: Int, durationMs: UInt64, message: String)
    case realtimePassCancelled(sampleCount: Int, durationMs: UInt64)
    case firstPartialLatency(durationMs: UInt64)
    case finalPassStarted(sampleCount: Int, confirmedEndSeconds: Float)
    case finalPassFinished(segmentCount: Int, emittedEventCount: Int, durationMs: UInt64)
    case finalPassFailed(durationMs: UInt64, message: String)
    case runtime(WhisperKitRuntimeMetric)
    case sessionFinished(totalSamples: Int, partialEvents: Int, committedEvents: Int, errorEvents: Int)
}

/// Native Argmax WhisperKit STT.
///
/// Audio is buffered during recording so the provider can run periodic native
/// WhisperKit passes for realtime partials, then commit a final pass when the
/// session stops.
public actor WhisperKitProvider: SttProvider {
    private let config: WhisperKitSttConfig
    private let language: String?
    private let runtimeStore: WhisperKitRuntimeStore
    private let realtimeOptions: WhisperKitRealtimeOptions
    private let onMetric: @Sendable (WhisperKitProviderMetric) -> Void

    private var sampleBuffer: [Int16] = []
    private var streamTask: Task<Void, Never>?
    private var isStopping = false
    private var lastRealtimeSampleCount = 0
    private var realtimeState = WhisperKitRealtimeState()
    private var sessionStartedAt: Date?
    private var totalSamplesReceived = 0
    private var partialEventCount = 0
    private var committedEventCount = 0
    private var errorEventCount = 0
    private var hasSeenFirstPartial = false
    private var sessionGeneration = 0

    private let eventContinuation: AsyncStream<TranscriptionEvent>.Continuation
    public nonisolated let events: AsyncStream<TranscriptionEvent>

    public init(
        config: WhisperKitSttConfig = WhisperKitSttConfig(),
        language: String? = nil,
        runtimeStore: WhisperKitRuntimeStore = .shared,
        realtimeOptions: WhisperKitRealtimeOptions = WhisperKitRealtimeOptions(),
        onMetric: @escaping @Sendable (WhisperKitProviderMetric) -> Void = { _ in }
    ) {
        self.config = config
        self.language = language
        self.runtimeStore = runtimeStore
        self.realtimeOptions = realtimeOptions
        self.onMetric = onMetric

        var cont: AsyncStream<TranscriptionEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.eventContinuation = cont
    }

    public func startSession() async throws {
        sessionGeneration += 1
        let generation = sessionGeneration
        sampleBuffer = []
        isStopping = false
        lastRealtimeSampleCount = 0
        realtimeState = WhisperKitRealtimeState(
            requiredSegmentsForConfirmation: realtimeOptions.requiredSegmentsForConfirmation
        )
        sessionStartedAt = Date()
        totalSamplesReceived = 0
        partialEventCount = 0
        committedEventCount = 0
        errorEventCount = 0
        hasSeenFirstPartial = false
        emitMetric(.sessionStarted(
            model: WhisperKitRuntimeKey(config: config).model,
            intervalMs: realtimeOptions.intervalMilliseconds,
            minimumSamples: realtimeOptions.minimumSamples,
            requiredSegmentsForConfirmation: realtimeOptions.requiredSegmentsForConfirmation
        ))
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            await self?.runRealtimeLoop(generation: generation)
        }
    }

    public func sendAudio(_ chunk: AudioChunk) async throws {
        sampleBuffer.append(contentsOf: chunk.data)
        totalSamplesReceived += chunk.data.count
        emitMetric(.audioReceived(
            totalSamples: totalSamplesReceived,
            chunkSamples: chunk.data.count,
            timestampMs: chunk.timestampMs
        ))
    }

    public func stopSession() async throws {
        defer {
            emitMetric(.sessionFinished(
                totalSamples: totalSamplesReceived,
                partialEvents: partialEventCount,
                committedEvents: committedEventCount,
                errorEvents: errorEventCount
            ))
            eventContinuation.finish()
        }

        isStopping = true
        sessionGeneration += 1
        streamTask?.cancel()
        streamTask = nil

        guard !sampleBuffer.isEmpty else { return }

        let samples = sampleBuffer
        sampleBuffer = []

        let startedAt = Date()
        emitMetric(.finalPassStarted(
            sampleCount: samples.count,
            confirmedEndSeconds: realtimeState.confirmedEndSeconds
        ))

        do {
            let segments = try await runtimeStore.transcribeSegments(
                samples: Self.floatSamples(from: samples),
                config: config,
                language: language,
                clipStartSeconds: realtimeState.confirmedEndSeconds,
                priority: .final,
                onStatus: { _ in },
                onMetric: runtimeMetricHandler()
            )
            let events = realtimeState.finalize(segments)
            emitMetric(.finalPassFinished(
                segmentCount: segments.count,
                emittedEventCount: events.count,
                durationMs: Self.elapsedMilliseconds(since: startedAt)
            ))
            for event in events {
                emit(event)
            }
        } catch {
            emitMetric(.finalPassFailed(
                durationMs: Self.elapsedMilliseconds(since: startedAt),
                message: error.localizedDescription
            ))
            emit(.error(message: "WhisperKit error: \(error.localizedDescription)"))
        }
    }

    public static func floatSamples(from samples: [Int16]) -> [Float] {
        samples.map { sample in
            max(-1.0, Float(sample) / Float(Int16.max))
        }
    }

    private func runRealtimeLoop(generation: Int) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: realtimeOptions.interval)
            } catch {
                return
            }

            if Task.isCancelled || isStopping || generation != sessionGeneration { return }

            let snapshot = realtimeSnapshot()
            guard let snapshot else { continue }

            let startedAt = Date()
            emitMetric(.realtimePassStarted(
                sampleCount: snapshot.sampleCount,
                confirmedEndSeconds: snapshot.confirmedEndSeconds
            ))

            do {
                let segments = try await runtimeStore.transcribeSegments(
                    samples: Self.floatSamples(from: snapshot.samples),
                    config: config,
                    language: language,
                    clipStartSeconds: snapshot.confirmedEndSeconds,
                    priority: .realtime,
                    onStatus: { _ in },
                    onMetric: runtimeMetricHandler()
                )
                let events = realtimeEvents(
                    segments,
                    sampleCount: snapshot.sampleCount,
                    generation: generation
                )
                emitMetric(.realtimePassFinished(
                    sampleCount: snapshot.sampleCount,
                    segmentCount: segments.count,
                    emittedEventCount: events.count,
                    durationMs: Self.elapsedMilliseconds(since: startedAt)
                ))
                for event in events {
                    emit(event)
                }
            } catch is CancellationError {
                emitMetric(.realtimePassCancelled(
                    sampleCount: snapshot.sampleCount,
                    durationMs: Self.elapsedMilliseconds(since: startedAt)
                ))
                return
            } catch {
                if !isStopping {
                    emitMetric(.realtimePassFailed(
                        sampleCount: snapshot.sampleCount,
                        durationMs: Self.elapsedMilliseconds(since: startedAt),
                        message: error.localizedDescription
                    ))
                    emit(.error(message: "WhisperKit realtime error: \(error.localizedDescription)"))
                }
                return
            }
        }
    }

    private func realtimeSnapshot() -> RealtimeSnapshot? {
        guard sampleBuffer.count >= realtimeOptions.minimumSamples else { return nil }
        guard sampleBuffer.count > lastRealtimeSampleCount else { return nil }

        return RealtimeSnapshot(
            samples: sampleBuffer,
            sampleCount: sampleBuffer.count,
            confirmedEndSeconds: realtimeState.confirmedEndSeconds
        )
    }

    private func realtimeEvents(
        _ segments: [WhisperKitTranscriptSegment],
        sampleCount: Int,
        generation: Int
    ) -> [TranscriptionEvent] {
        guard !isStopping, generation == sessionGeneration else { return [] }
        lastRealtimeSampleCount = sampleCount
        return realtimeState.handleHypothesis(segments)
    }

    private func emit(_ event: TranscriptionEvent) {
        switch event {
        case .partial(let text, _):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { break }
            partialEventCount += 1
            if !hasSeenFirstPartial, let sessionStartedAt {
                hasSeenFirstPartial = true
                emitMetric(.firstPartialLatency(durationMs: Self.elapsedMilliseconds(since: sessionStartedAt)))
            }
        case .committed:
            committedEventCount += 1
        case .error:
            errorEventCount += 1
        }
        eventContinuation.yield(event)
    }

    private func runtimeMetricHandler() -> @Sendable (WhisperKitRuntimeMetric) -> Void {
        { [onMetric] metric in
            onMetric(.runtime(metric))
        }
    }

    private func emitMetric(_ metric: WhisperKitProviderMetric) {
        onMetric(metric)
    }

    private static func elapsedMilliseconds(since start: Date) -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince(start) * 1000))
    }

    private struct RealtimeSnapshot: Sendable {
        var samples: [Int16]
        var sampleCount: Int
        var confirmedEndSeconds: Float
    }
}
