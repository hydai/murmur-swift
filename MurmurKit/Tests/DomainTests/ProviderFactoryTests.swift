import Foundation
import Testing
@testable import MurmurKit

@Suite("ProviderFactory tests")
struct ProviderFactoryTests {

    private func withTempFactory(_ body: (ProviderFactory) async throws -> Void) async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let factory = ProviderFactory(configDir: tempDir)
        try await body(factory)
    }

    @Test("STT provider mapping")
    func testSttProviderMapping() async throws {
        try await withTempFactory { factory in
            var config = AppConfig()

            // Apple STT
            config.sttProvider = .appleStt
            let apple = factory.createSttProvider(from: config)
            #expect(apple is AppleSttProvider)

            // WhisperKit
            config.sttProvider = .whisperKit
            let whisperKit = factory.createSttProvider(from: config)
            #expect(whisperKit is WhisperKitProvider)

            // ElevenLabs
            config.sttProvider = .elevenLabs
            let elevenLabs = factory.createSttProvider(from: config)
            #expect(elevenLabs is ElevenLabsProvider)

            // OpenAI
            config.sttProvider = .openAI
            let openAI = factory.createSttProvider(from: config)
            #expect(openAI is OpenAIProvider)

            // Groq
            config.sttProvider = .groq
            let groq = factory.createSttProvider(from: config)
            #expect(groq is GroqProvider)

            // Custom
            config.sttProvider = .customStt
            let custom = factory.createSttProvider(from: config)
            #expect(custom is CustomSttProvider)
        }
    }

    @Test("WhisperKit STT provider forwards injected metrics")
    func whisperKitProviderForwardsInjectedMetrics() async throws {
        let recorder = ProviderMetricRecorder()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let factory = ProviderFactory(
            configDir: tempDir,
            whisperKitMetricHandler: { recorder.append($0) }
        )
        var config = AppConfig()
        config.sttProvider = .whisperKit

        let provider = factory.createSttProvider(from: config)
        try await provider.startSession()
        try await provider.stopSession()

        let metrics = recorder.snapshot()
        #expect(metrics.contains { metric in
            if case .sessionStarted = metric {
                return true
            }
            return false
        })
        #expect(metrics.contains { metric in
            if case .sessionFinished = metric {
                return true
            }
            return false
        })
    }

    @Test("LLM processor mapping")
    func testLlmProcessorMapping() async throws {
        try await withTempFactory { factory in
            var config = AppConfig()

            config.llmProcessor = .appleLlm
            let apple = await factory.createLlmProcessor(from: config)
            #expect(apple is AppleLlmProcessor)

            config.llmProcessor = .gemini
            let gemini = await factory.createLlmProcessor(from: config)
            #expect(gemini is GeminiProcessor)

            config.llmProcessor = .copilot
            let copilot = await factory.createLlmProcessor(from: config)
            #expect(copilot is CopilotProcessor)

            config.llmProcessor = .openAILlm
            let openAI = await factory.createLlmProcessor(from: config)
            #expect(openAI is OpenAILlmProcessor)

            config.llmProcessor = .claude
            let claude = await factory.createLlmProcessor(from: config)
            #expect(claude is ClaudeLlmProcessor)

            config.llmProcessor = .geminiApi
            let geminiApi = await factory.createLlmProcessor(from: config)
            #expect(geminiApi is GeminiApiProcessor)

            config.llmProcessor = .customOpenAI
            let customOpenAI = await factory.createLlmProcessor(from: config)
            #expect(customOpenAI is CustomOpenAIProcessor)
        }
    }

    @Test("Model override mapping")
    func testModelOverride() async throws {
        try await withTempFactory { factory in
            var config = AppConfig()
            config.llmProcessor = .geminiApi
            config.llmModel = "custom-override-model"

            let processor = await factory.createLlmProcessor(from: config) as? GeminiApiProcessor
            #expect(processor != nil)

            // Assert the effective model using reflection
            if let processor = processor {
                let mirror = Mirror(reflecting: processor)
                let modelValue = mirror.children.first { $0.label == "model" }?.value as? String
                #expect(modelValue == "custom-override-model")
            }
        }
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
