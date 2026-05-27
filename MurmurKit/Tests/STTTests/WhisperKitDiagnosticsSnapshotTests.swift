import Testing
@testable import MurmurKit

@Suite("WhisperKitDiagnosticsSnapshot")
struct WhisperKitDiagnosticsSnapshotTests {
    @Test("Provider metrics update session, realtime, final, and event counters")
    func providerMetricsUpdateTranscriptionDiagnostics() {
        var snapshot = WhisperKitDiagnosticsSnapshot()

        #expect(!snapshot.hasData)
        #expect(snapshot.modelText == "No model yet")
        #expect(snapshot.modelSourceText == "No source yet")

        snapshot.apply(.sessionStarted(
            model: "tiny",
            intervalMs: 500,
            minimumSamples: 8_000,
            requiredSegmentsForConfirmation: 1
        ))
        snapshot.apply(.audioReceived(totalSamples: 16_000, chunkSamples: 4_000, timestampMs: 10))
        snapshot.apply(.realtimePassFinished(
            sampleCount: 16_000,
            segmentCount: 2,
            emittedEventCount: 1,
            durationMs: 123
        ))
        snapshot.apply(.firstPartialLatency(durationMs: 456))
        snapshot.apply(.finalPassFinished(segmentCount: 3, emittedEventCount: 2, durationMs: 789))
        snapshot.apply(.sessionFinished(
            totalSamples: 32_000,
            partialEvents: 4,
            committedEvents: 5,
            errorEvents: 0
        ))

        #expect(snapshot.hasData)
        #expect(snapshot.model == "tiny")
        #expect(snapshot.modelText == "tiny")
        #expect(snapshot.sessionStartedAt != nil)
        #expect(snapshot.intervalMs == 500)
        #expect(snapshot.minimumSamples == 8_000)
        #expect(snapshot.requiredSegmentsForConfirmation == 1)
        #expect(snapshot.totalSamples == 32_000)
        #expect(snapshot.lastRealtimeDurationMs == 123)
        #expect(snapshot.lastRealtimeSampleCount == 16_000)
        #expect(snapshot.lastRealtimeSegmentCount == 2)
        #expect(snapshot.firstPartialLatencyMs == 456)
        #expect(snapshot.lastFinalDurationMs == 789)
        #expect(snapshot.lastFinalSegmentCount == 3)
        #expect(snapshot.partialEventCount == 4)
        #expect(snapshot.committedEventCount == 5)
        #expect(snapshot.errorEventCount == 0)
        #expect(snapshot.recentEvents.first?.title == "Session finished")
        #expect(snapshot.recentEvents.first?.detail == "5 committed, 4 partial")
    }

    @Test("Runtime metrics update model source, cache, load, and native transcription fields")
    func runtimeMetricsUpdateModelDiagnostics() {
        var snapshot = WhisperKitDiagnosticsSnapshot()
        let remoteKey = WhisperKitRuntimeKey(config: WhisperKitSttConfig(
            model: "tiny",
            modelRepo: "example/repo"
        ))

        snapshot.apply(.downloadFinished(key: remoteKey, modelFolder: "/cache/tiny", durationMs: 11))
        snapshot.apply(.loadFinished(key: remoteKey, durationMs: 22))
        snapshot.apply(.transcriptionStarted(key: remoteKey, sampleCount: 16_000, clipStartSeconds: nil))
        snapshot.apply(.transcriptionFinished(key: remoteKey, segmentCount: 2, durationMs: 33))
        snapshot.apply(.cacheHit(key: remoteKey))

        #expect(snapshot.model == "tiny")
        #expect(snapshot.modelRepo == "example/repo")
        #expect(!snapshot.usesCustomModelFolder)
        #expect(snapshot.modelSourceText == "Model cache")
        #expect(snapshot.lastDownloadDurationMs == 11)
        #expect(snapshot.lastLoadDurationMs == 22)
        #expect(snapshot.lastNativeTranscriptionSampleCount == 16_000)
        #expect(snapshot.lastNativeTranscriptionDurationMs == 33)
        #expect(snapshot.cacheHitCount == 1)

        let localKey = WhisperKitRuntimeKey(config: WhisperKitSttConfig(
            model: "tiny",
            modelRepo: "example/repo",
            modelFolder: " /tmp/local-tiny "
        ))
        snapshot.apply(.cacheHit(key: localKey))

        #expect(snapshot.usesCustomModelFolder)
        #expect(snapshot.modelSourceText == "Local folder")
        #expect(snapshot.cacheHitCount == 2)
    }

    @Test("Provider runtime wrapper metrics use the same reducer path")
    func providerRuntimeMetricUsesRuntimeReducer() {
        var snapshot = WhisperKitDiagnosticsSnapshot()
        let key = WhisperKitRuntimeKey(config: WhisperKitSttConfig(model: "tiny"))

        snapshot.apply(.runtime(.loadFinished(key: key, durationMs: 44)))

        #expect(snapshot.model == "tiny")
        #expect(snapshot.lastLoadDurationMs == 44)
        #expect(snapshot.recentEvents.first?.title == "Load finished")
    }

    @Test("Errors are recorded and cleared when a new session starts")
    func errorsClearOnNewSession() {
        var snapshot = WhisperKitDiagnosticsSnapshot()
        let key = WhisperKitRuntimeKey(config: WhisperKitSttConfig(model: "tiny"))

        snapshot.apply(.downloadFailed(key: key, durationMs: 55, message: "download failed"))

        #expect(snapshot.lastError == "download failed")
        #expect(snapshot.errorEventCount == 1)
        #expect(snapshot.recentEvents.first?.level == .error)

        snapshot.apply(.sessionStarted(
            model: "tiny",
            intervalMs: 1_500,
            minimumSamples: 16_000,
            requiredSegmentsForConfirmation: 2
        ))

        #expect(snapshot.lastError == nil)
        #expect(snapshot.errorEventCount == 0)
    }

    @Test("Recent events keep the newest eight entries")
    func recentEventsKeepNewestEightEntries() {
        var snapshot = WhisperKitDiagnosticsSnapshot()

        for index in 0..<10 {
            snapshot.apply(.audioReceived(
                totalSamples: index,
                chunkSamples: index,
                timestampMs: UInt64(index)
            ))
        }

        #expect(snapshot.recentEvents.count == 8)
        #expect(snapshot.recentEvents.first?.detail == "9 samples")
        #expect(snapshot.recentEvents.last?.detail == "2 samples")
    }
}
