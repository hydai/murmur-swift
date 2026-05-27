import Foundation
import Testing
@testable import MurmurKit

@Suite("WhisperKitProvider")
struct WhisperKitProviderTests {
    @Test("Construction with default parameters")
    func defaultConstruction() async {
        let provider = WhisperKitProvider()
        let events = provider.events
        _ = events
    }

    @Test("Construction with custom parameters")
    func customConstruction() async {
        let provider = WhisperKitProvider(
            config: WhisperKitSttConfig(
                model: "tiny",
                modelRepo: "example/models",
                modelFolder: "/tmp/models",
                prewarm: true
            ),
            language: "zh",
            runtimeStore: WhisperKitRuntimeStore()
        )
        let events = provider.events
        _ = events
    }

    @Test("Converts Int16 PCM to normalized float samples")
    func convertsInt16ToFloatSamples() {
        let samples = WhisperKitProvider.floatSamples(from: [Int16.min, 0, Int16.max])

        #expect(samples.count == 3)
        #expect(samples[0] == -1)
        #expect(samples[1] == 0)
        #expect(samples[2] == 1)
    }

    @Test("Realtime options clamp unsafe values")
    func realtimeOptionsClampUnsafeValues() {
        let options = WhisperKitRealtimeOptions(
            intervalMilliseconds: 1,
            minimumSamples: 0,
            requiredSegmentsForConfirmation: -1
        )

        #expect(options.intervalMilliseconds == 100)
        #expect(options.minimumSamples == 1)
        #expect(options.requiredSegmentsForConfirmation == 0)
    }

    @Test("Runtime key normalizes empty config values")
    func runtimeKeyNormalizesEmptyConfigValues() {
        let key = WhisperKitRuntimeKey(
            config: WhisperKitSttConfig(
                model: "  ",
                modelRepo: "\n",
                modelFolder: " /tmp/whisperkit ",
                prewarm: true
            )
        )

        #expect(key.model == ProviderDefaults.whisperKitSttModel)
        #expect(key.modelRepo == ProviderDefaults.whisperKitModelRepo)
        #expect(key.modelFolder == "/tmp/whisperkit")
    }

    @Test("Runtime status marks loading states as busy")
    func runtimeStatusBusyStates() {
        #expect(WhisperKitModelStatus.downloading(0.4).isBusy)
        #expect(WhisperKitModelStatus.loading.isBusy)
        #expect(WhisperKitModelStatus.prewarming.isBusy)
        #expect(!WhisperKitModelStatus.idle.isBusy)
        #expect(!WhisperKitModelStatus.ready.isBusy)
        #expect(!WhisperKitModelStatus.error("failed").isBusy)
    }

    @Test("Runtime store starts idle for uncached config")
    func runtimeStoreStartsIdle() async {
        let store = WhisperKitRuntimeStore()
        let status = await store.status(for: WhisperKitSttConfig(model: "tiny"))

        #expect(status == .idle)
    }

    @Test("Runtime store prioritizes final transcription slots")
    func runtimeStorePrioritizesFinalTranscriptionSlots() async throws {
        let store = WhisperKitRuntimeStore()
        let key = WhisperKitRuntimeKey(config: WhisperKitSttConfig(model: "tiny"))
        let gate = AsyncGate()
        let probe = RuntimeSlotProbe()

        let first = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .standard) {
                await probe.append("first")
                await gate.wait()
            }
        }
        await probe.waitForStartedCount(1)

        let realtime = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .realtime) {
                await probe.append("realtime")
            }
        }
        try await waitUntilWaiterCount(1, store: store, key: key)

        let final = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .final) {
                await probe.append("final")
            }
        }
        try await waitUntilWaiterCount(2, store: store, key: key)

        await gate.open()
        try await first.value
        try await final.value
        try await realtime.value

        let started = await probe.snapshot()
        #expect(started == ["first", "final", "realtime"])
    }

    @Test("Runtime store removes cancelled queued transcription slots")
    func runtimeStoreRemovesCancelledQueuedTranscriptionSlots() async throws {
        let store = WhisperKitRuntimeStore()
        let key = WhisperKitRuntimeKey(config: WhisperKitSttConfig(model: "tiny"))
        let gate = AsyncGate()
        let probe = RuntimeSlotProbe()

        let first = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .standard) {
                await probe.append("first")
                await gate.wait()
            }
        }
        await probe.waitForStartedCount(1)

        let cancelled = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .realtime) {
                await probe.append("cancelled")
            }
        }
        try await waitUntilWaiterCount(1, store: store, key: key)
        cancelled.cancel()
        try await waitUntilWaiterCount(0, store: store, key: key)

        let next = Task {
            try await store.withTranscriptionSlotForTesting(key: key, priority: .standard) {
                await probe.append("next")
            }
        }
        try await waitUntilWaiterCount(1, store: store, key: key)

        await gate.open()
        try await first.value
        try await next.value

        do {
            try await cancelled.value
            Issue.record("Expected queued realtime slot to be cancelled")
        } catch is CancellationError {
        }

        let started = await probe.snapshot()
        #expect(started == ["first", "next"])
    }

    @Test("Realtime state emits partial before segments are stable")
    func realtimeStateEmitsPartialBeforeStableSegments() {
        var state = WhisperKitRealtimeState(requiredSegmentsForConfirmation: 1)

        let events = state.handleHypothesis([
            WhisperKitTranscriptSegment(text: "Hello", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2)
        ])

        #expect(events.count == 1)
        #expect(isPartial(events[0], "Hello world"))
        #expect(state.confirmedEndSeconds == 0)
    }

    @Test("Realtime state commits stable prefix and keeps suffix partial")
    func realtimeStateCommitsStablePrefix() {
        var state = WhisperKitRealtimeState(requiredSegmentsForConfirmation: 1)
        _ = state.handleHypothesis([
            WhisperKitTranscriptSegment(text: "Hello", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2)
        ])

        let events = state.handleHypothesis([
            WhisperKitTranscriptSegment(text: " Hello ", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2),
            WhisperKitTranscriptSegment(text: "again", start: 2, end: 3)
        ])

        #expect(events.count == 2)
        #expect(isCommitted(events[0], "Hello"))
        #expect(isPartial(events[1], "world again"))
        #expect(state.confirmedEndSeconds == 1)
    }

    @Test("Realtime state finalizes only uncommitted segments")
    func realtimeStateFinalizesUncommittedSegmentsOnly() {
        var state = WhisperKitRealtimeState(requiredSegmentsForConfirmation: 1)
        _ = state.handleHypothesis([
            WhisperKitTranscriptSegment(text: "Hello", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2)
        ])
        _ = state.handleHypothesis([
            WhisperKitTranscriptSegment(text: "Hello", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2),
            WhisperKitTranscriptSegment(text: "again", start: 2, end: 3)
        ])

        let events = state.finalize([
            WhisperKitTranscriptSegment(text: "Hello", start: 0, end: 1),
            WhisperKitTranscriptSegment(text: "world", start: 1, end: 2),
            WhisperKitTranscriptSegment(text: "again", start: 2, end: 3)
        ])

        #expect(events.count == 1)
        #expect(isCommitted(events[0], "world again"))
        #expect(state.confirmedEndSeconds == 3)
    }

    private func isPartial(_ event: TranscriptionEvent, _ text: String) -> Bool {
        if case .partial(let value, _) = event {
            return value == text
        }
        return false
    }

    private func isCommitted(_ event: TranscriptionEvent, _ text: String) -> Bool {
        if case .committed(let value, _) = event {
            return value == text
        }
        return false
    }

    private func waitUntilWaiterCount(
        _ expectedCount: Int,
        store: WhisperKitRuntimeStore,
        key: WhisperKitRuntimeKey
    ) async throws {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            let count = await store.waiterCountForTesting(for: key)
            if count == expectedCount {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw WhisperKitProviderTestError.timeout("Expected \(expectedCount) queued waiter(s)")
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiters = waiters
        self.waiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor RuntimeSlotProbe {
    private var started: [String] = []
    private var countWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func append(_ value: String) {
        started.append(value)
        resumeReadyWaiters()
    }

    func snapshot() -> [String] {
        started
    }

    func waitForStartedCount(_ count: Int) async {
        guard started.count < count else { return }
        await withCheckedContinuation { continuation in
            countWaiters.append((count, continuation))
        }
    }

    private func resumeReadyWaiters() {
        let ready = countWaiters.filter { started.count >= $0.count }
        countWaiters.removeAll { started.count >= $0.count }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}

private enum WhisperKitProviderTestError: Error {
    case timeout(String)
}
