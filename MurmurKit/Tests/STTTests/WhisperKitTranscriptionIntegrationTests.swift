import Foundation
import Testing
@testable import MurmurKit

@Suite("WhisperKit transcription integration")
struct WhisperKitTranscriptionIntegrationTests {
    @Test("Provider emits realtime partial and final transcript for real audio")
    func providerEmitsRealtimePartialAndFinalTranscript() async throws {
        guard ProcessInfo.processInfo.environment["MURMUR_RUN_WHISPERKIT_TRANSCRIPTION_E2E"] == "1" else {
            return
        }

        let previousHome = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"]
        let tempHome = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-whisperkit-transcription-e2e-\(UUID().uuidString)")
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

        let config = WhisperKitSttConfig(
            model: "tiny",
            modelRepo: ProviderDefaults.whisperKitModelRepo,
            modelFolder: "",
            prewarm: false
        )
        let runtimeStore = WhisperKitRuntimeStore()
        try await runtimeStore.preload(config: config) { status in
            print("[WhisperKit transcription E2E] preload status=\(status)")
        }

        let samples = try loadJfkSamples()
        let provider = WhisperKitProvider(
            config: config,
            language: "en",
            runtimeStore: runtimeStore,
            realtimeInterval: .milliseconds(250),
            realtimeMinimumSamples: 16000
        )
        let recorder = TranscriptionEventRecorder()
        let collector = Task {
            for await event in provider.events {
                await recorder.append(event)
                print("[WhisperKit transcription E2E] event=\(event)")
            }
        }

        try await provider.startSession()

        let firstPassSamples = Array(samples.prefix(16000 * 4))
        try await provider.sendAudio(AudioChunk(data: firstPassSamples, timestampMs: 0))
        let partialSeen = await waitForPartialOrError(in: recorder, timeoutSeconds: 30)
        #expect(partialSeen)

        let remainingSamples = Array(samples.dropFirst(firstPassSamples.count))
        try await provider.sendAudio(AudioChunk(data: remainingSamples, timestampMs: UInt64(firstPassSamples.count) * 1000 / 16000))
        try await provider.stopSession()
        await collector.value

        let events = await recorder.snapshot()
        #expect(!events.containsError)
        #expect(events.containsPartial)
        #expect(!events.transcriptText.contains("<|"))

        let finalTranscript = events.committedTranscript
        let normalizedTranscript = normalize(finalTranscript)
        #expect(normalizedTranscript.contains("my fellow americans"))
        #expect(normalizedTranscript.contains("your country"))

        await runtimeStore.evict(config: config)
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

    private func loadJfkSamples() throws -> [Int16] {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot.appendingPathComponent(
            ".build/checkouts/argmax-oss-swift/Tests/WhisperKitTests/Resources/jfk.wav"
        )
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

private enum E2EError: Error {
    case invalidWav(String)
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
