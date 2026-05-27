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
}
