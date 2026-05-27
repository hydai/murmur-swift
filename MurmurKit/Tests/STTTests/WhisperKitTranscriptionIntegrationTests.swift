import Foundation
import Testing
@testable import MurmurKit

@Suite("WhisperKit transcription integration", .serialized)
struct WhisperKitTranscriptionIntegrationTests {
    @Test("Provider emits realtime partial and final transcript for real audio")
    func providerEmitsRealtimePartialAndFinalTranscript() async throws {
        guard Self.isEnabled("MURMUR_RUN_WHISPERKIT_TRANSCRIPTION_E2E") else {
            return
        }

        try await withTemporaryFixedUserHome(prefix: "murmur-whisperkit-transcription-e2e") {
            let config = Self.tinyRemoteConfig()
            let runtimeStore = WhisperKitRuntimeStore()
            try await runtimeStore.preload(config: config) { status in
                print("[WhisperKit transcription E2E] preload status=\(status)")
            }

            let run = try await runProviderTranscription(
                fixture: .jfkRealtime,
                config: config,
                runtimeStore: runtimeStore
            )

            assertTranscript(run.events, contains: ["my fellow americans", "your country"])
            #expect(run.events.containsPartial)
            #expect(run.metrics.containsFirstPartialLatency)
            #expect(run.metrics.containsFinalPassFinished)
            #expect(run.metrics.containsRuntimeCacheHit)
            #expect(run.metrics.containsRuntimeTranscriptionFinished)

            await runtimeStore.evict(config: config)
        }
    }

    @Test("Provider covers expanded tiny model transcription matrix")
    func providerCoversExpandedTinyModelTranscriptionMatrix() async throws {
        guard Self.isEnabled("MURMUR_RUN_WHISPERKIT_TRANSCRIPTION_MATRIX_E2E") else {
            return
        }

        try await withTemporaryFixedUserHome(prefix: "murmur-whisperkit-transcription-matrix-e2e") {
            let config = Self.tinyRemoteConfig()
            let runtimeStore = WhisperKitRuntimeStore()
            try await runtimeStore.preload(config: config) { status in
                print("[WhisperKit matrix E2E] preload status=\(status)")
            }

            let fixtures: [WhisperKitAudioFixture] = [
                .jfkRealtime,
                WhisperKitAudioFixture(
                    name: "spanish explicit",
                    audioFile: "es_test_clip.wav",
                    language: "es",
                    expectedPhrases: ["esta es una"]
                ),
                WhisperKitAudioFixture(
                    name: "spanish auto",
                    audioFile: "es_test_clip.wav",
                    language: nil,
                    expectedPhrases: ["esta es una"]
                ),
                WhisperKitAudioFixture(
                    name: "japanese explicit",
                    audioFile: "ja_test_clip.wav",
                    language: "ja",
                    expectedPhrases: ["\u{6771}\u{4EAC}"]
                ),
            ]

            for fixture in fixtures {
                let run = try await runProviderTranscription(
                    fixture: fixture,
                    config: config,
                    runtimeStore: runtimeStore
                )
                assertTranscript(run.events, contains: fixture.expectedPhrases)
                #expect(run.metrics.containsFinalPassFinished)
                #expect(run.metrics.containsRuntimeTranscriptionFinished)
            }

            try await verifyLocalModelFolderTranscription(from: config)

            await runtimeStore.evict(config: config)
        }
    }

    @Test("Provider transcribes with production default model")
    func providerTranscribesWithProductionDefaultModel() async throws {
        guard Self.isEnabled("MURMUR_RUN_WHISPERKIT_DEFAULT_MODEL_E2E") else {
            return
        }

        try await withTemporaryFixedUserHome(prefix: "murmur-whisperkit-default-model-e2e") {
            let config = WhisperKitSttConfig()
            let runtimeStore = WhisperKitRuntimeStore()
            try await runtimeStore.preload(config: config) { status in
                print("[WhisperKit default model E2E] preload status=\(status)")
            }

            let run = try await runProviderTranscription(
                fixture: WhisperKitAudioFixture(
                    name: "default model JFK",
                    audioFile: "jfk.wav",
                    language: "en",
                    expectedPhrases: ["my fellow americans", "your country"]
                ),
                config: config,
                runtimeStore: runtimeStore
            )
            assertTranscript(run.events, contains: ["my fellow americans", "your country"])
            #expect(run.metrics.containsFinalPassFinished)
            #expect(run.metrics.containsRuntimeTranscriptionFinished)

            await runtimeStore.evict(config: config)
        }
    }

    private func waitForPartialOrError(
        in recorder: TranscriptionEventRecorder,
        timeoutSeconds: Int
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            let events = await recorder.snapshot()
            if events.containsPartial {
                return true
            }
            if events.containsError {
                return false
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    private func runProviderTranscription(
        fixture: WhisperKitAudioFixture,
        config: WhisperKitSttConfig,
        runtimeStore: WhisperKitRuntimeStore
    ) async throws -> (events: [TranscriptionEvent], metrics: [WhisperKitProviderMetric]) {
        let samples = try loadFixtureSamples(fixture.audioFile)
        let metrics = ProviderMetricRecorder()
        let provider = WhisperKitProvider(
            config: config,
            language: fixture.language,
            runtimeStore: runtimeStore,
            realtimeOptions: WhisperKitRealtimeOptions(
                intervalMilliseconds: 250,
                minimumSamples: 16000,
                requiredSegmentsForConfirmation: 2
            ),
            onMetric: { metric in
                metrics.append(metric)
                print("[WhisperKit transcription E2E][\(fixture.name)] metric=\(metric)")
            }
        )
        let recorder = TranscriptionEventRecorder()
        let collector = Task {
            for await event in provider.events {
                await recorder.append(event)
                print("[WhisperKit transcription E2E][\(fixture.name)] event=\(event)")
            }
        }

        try await provider.startSession()

        if let realtimePrefixSampleCount = fixture.realtimePrefixSampleCount {
            let firstPassSamples = Array(samples.prefix(realtimePrefixSampleCount))
            try await provider.sendAudio(AudioChunk(data: firstPassSamples, timestampMs: 0))
            let partialSeen = await waitForPartialOrError(in: recorder, timeoutSeconds: 30)
            #expect(partialSeen)

            let remainingSamples = Array(samples.dropFirst(firstPassSamples.count))
            try await sendSamples(remainingSamples, to: provider, startingAtSample: firstPassSamples.count)
        } else {
            try await sendSamples(samples, to: provider)
        }

        try await provider.stopSession()
        await collector.value

        return (await recorder.snapshot(), metrics.snapshot())
    }

    private func verifyLocalModelFolderTranscription(from remoteConfig: WhisperKitSttConfig) async throws {
        let manager = WhisperKitModelManager()
        let inventory = await manager.inventory(for: remoteConfig)
        guard case .remoteCached(let cachedPath, _) = inventory.storageStatus else {
            Issue.record("Expected tiny model to be cached before local-folder E2E, got \(inventory.storageStatus)")
            return
        }

        let localConfig = WhisperKitSttConfig(
            model: remoteConfig.model,
            modelRepo: remoteConfig.modelRepo,
            modelFolder: cachedPath,
            prewarm: false
        )
        let localInventory = await manager.inventory(for: localConfig)
        guard case .localReady = localInventory.storageStatus else {
            Issue.record("Expected local model folder to be ready, got \(localInventory.storageStatus)")
            return
        }

        let localRuntimeStore = WhisperKitRuntimeStore()
        let run = try await runProviderTranscription(
            fixture: WhisperKitAudioFixture(
                name: "local model folder JFK",
                audioFile: "jfk.wav",
                language: "en",
                expectedPhrases: ["my fellow americans", "your country"]
            ),
            config: localConfig,
            runtimeStore: localRuntimeStore
        )
        assertTranscript(run.events, contains: ["my fellow americans", "your country"])
        #expect(!run.metrics.containsRuntimeDownloadStarted)
        #expect(run.metrics.containsRuntimeLoadFinished)

        await localRuntimeStore.evict(config: localConfig)
    }

    private func sendSamples(
        _ samples: [Int16],
        to provider: WhisperKitProvider,
        startingAtSample: Int = 0,
        chunkSize: Int = 8000
    ) async throws {
        guard !samples.isEmpty else { return }

        var offset = 0
        while offset < samples.count {
            let end = min(offset + chunkSize, samples.count)
            let chunk = Array(samples[offset..<end])
            let absoluteSampleOffset = startingAtSample + offset
            try await provider.sendAudio(AudioChunk(
                data: chunk,
                timestampMs: UInt64(absoluteSampleOffset) * 1000 / 16000
            ))
            offset = end
        }
    }

    private func assertTranscript(_ events: [TranscriptionEvent], contains expectedPhrases: [String]) {
        #expect(!events.containsError)
        #expect(!events.transcriptText.contains("<|"))

        let normalizedTranscript = normalize(events.committedTranscript)
        for phrase in expectedPhrases {
            #expect(normalizedTranscript.contains(normalize(phrase)))
        }
    }

    private func loadFixtureSamples(_ filename: String) throws -> [Int16] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot
            .appendingPathComponent(".build/checkouts/argmax-oss-swift/Tests/WhisperKitTests/Resources")
            .appendingPathComponent(filename)
        return try loadMono16kInt16Wav(from: url)
    }

    private func loadMono16kInt16Wav(from url: URL) throws -> [Int16] {
        let data = try Data(contentsOf: url)
        guard data.count >= 12,
              String(bytes: data[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: data[8..<12], encoding: .ascii) == "WAVE"
        else {
            throw E2EError.invalidWav("Missing RIFF/WAVE header")
        }

        var cursor = 12
        var sawPcmFormat = false
        var audioData: Data?

        while cursor + 8 <= data.count {
            let chunkID = String(bytes: data[cursor..<(cursor + 4)], encoding: .ascii) ?? ""
            let chunkSize = Int(readUInt32LE(data, at: cursor + 4))
            let chunkStart = cursor + 8
            let chunkEnd = min(chunkStart + chunkSize, data.count)

            if chunkID == "fmt " {
                let audioFormat = readUInt16LE(data, at: chunkStart)
                let channels = readUInt16LE(data, at: chunkStart + 2)
                let sampleRate = readUInt32LE(data, at: chunkStart + 4)
                let bitsPerSample = readUInt16LE(data, at: chunkStart + 14)
                sawPcmFormat = audioFormat == 1
                    && channels == 1
                    && sampleRate == 16000
                    && bitsPerSample == 16
            } else if chunkID == "data" {
                audioData = data[chunkStart..<chunkEnd]
                break
            }

            cursor = chunkEnd + (chunkSize % 2)
        }

        guard sawPcmFormat else {
            throw E2EError.invalidWav("Expected 16 kHz mono Int16 PCM")
        }
        guard let audioData else {
            throw E2EError.invalidWav("Missing data chunk")
        }

        var samples: [Int16] = []
        samples.reserveCapacity(audioData.count / 2)
        var index = audioData.startIndex
        while index + 1 < audioData.endIndex {
            let low = UInt16(audioData[index])
            let high = UInt16(audioData[index + 1]) << 8
            samples.append(Int16(bitPattern: high | low))
            index += 2
        }
        return samples
    }

    private func readUInt16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func readUInt32LE(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private func normalize(_ text: String) -> String {
        String(text
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func withTemporaryFixedUserHome<T>(
        prefix: String,
        operation: () async throws -> T
    ) async throws -> T {
        let previousHome = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"]
        let tempHome = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Documents"),
            withIntermediateDirectories: true
        )
        setenv("CFFIXED_USER_HOME", tempHome.path, 1)
        defer {
            if let previousHome {
                setenv("CFFIXED_USER_HOME", previousHome, 1)
            } else {
                unsetenv("CFFIXED_USER_HOME")
            }
            try? FileManager.default.removeItem(at: tempHome)
        }
        return try await operation()
    }

    private static func tinyRemoteConfig() -> WhisperKitSttConfig {
        WhisperKitSttConfig(
            model: "tiny",
            modelRepo: ProviderDefaults.whisperKitModelRepo,
            modelFolder: "",
            prewarm: false
        )
    }

    private static func isEnabled(_ environmentVariable: String) -> Bool {
        ProcessInfo.processInfo.environment[environmentVariable] == "1"
    }
}

private struct WhisperKitAudioFixture {
    var name: String
    var audioFile: String
    var language: String?
    var expectedPhrases: [String]
    var realtimePrefixSampleCount: Int?

    static let jfkRealtime = WhisperKitAudioFixture(
        name: "JFK realtime",
        audioFile: "jfk.wav",
        language: "en",
        expectedPhrases: ["my fellow americans", "your country"],
        realtimePrefixSampleCount: 16000 * 4
    )

    init(
        name: String,
        audioFile: String,
        language: String?,
        expectedPhrases: [String],
        realtimePrefixSampleCount: Int? = nil
    ) {
        self.name = name
        self.audioFile = audioFile
        self.language = language
        self.expectedPhrases = expectedPhrases
        self.realtimePrefixSampleCount = realtimePrefixSampleCount
    }
}

private actor TranscriptionEventRecorder {
    private var events: [TranscriptionEvent] = []

    func append(_ event: TranscriptionEvent) {
        events.append(event)
    }

    func snapshot() -> [TranscriptionEvent] {
        events
    }
}

private final class ProviderMetricRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var metrics: [WhisperKitProviderMetric] = []

    func append(_ metric: WhisperKitProviderMetric) {
        lock.lock()
        defer { lock.unlock() }
        metrics.append(metric)
    }

    func snapshot() -> [WhisperKitProviderMetric] {
        lock.lock()
        defer { lock.unlock() }
        return metrics
    }
}

private enum E2EError: Error {
    case invalidWav(String)
}

private extension [WhisperKitProviderMetric] {
    var containsFirstPartialLatency: Bool {
        contains { metric in
            if case .firstPartialLatency = metric {
                return true
            }
            return false
        }
    }

    var containsFinalPassFinished: Bool {
        contains { metric in
            if case .finalPassFinished = metric {
                return true
            }
            return false
        }
    }

    var containsRuntimeCacheHit: Bool {
        contains { metric in
            if case .runtime(.cacheHit(key: _)) = metric {
                return true
            }
            return false
        }
    }

    var containsRuntimeDownloadStarted: Bool {
        contains { metric in
            if case .runtime(.downloadStarted(key: _)) = metric {
                return true
            }
            return false
        }
    }

    var containsRuntimeLoadFinished: Bool {
        contains { metric in
            if case .runtime(.loadFinished(key: _, durationMs: _)) = metric {
                return true
            }
            return false
        }
    }

    var containsRuntimeTranscriptionFinished: Bool {
        contains { metric in
            if case .runtime(.transcriptionFinished(key: _, segmentCount: _, durationMs: _)) = metric {
                return true
            }
            return false
        }
    }
}

private extension [TranscriptionEvent] {
    var containsPartial: Bool {
        contains { event in
            if case .partial(let text, _) = event {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
    }

    var containsError: Bool {
        contains { event in
            if case .error = event {
                return true
            }
            return false
        }
    }

    var committedTranscript: String {
        compactMap { event in
            if case .committed(let text, _) = event {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    var transcriptText: String {
        compactMap { event in
            switch event {
            case .partial(let text, _), .committed(let text, _):
                return text
            case .error:
                return nil
            }
        }
        .joined(separator: " ")
    }
}
