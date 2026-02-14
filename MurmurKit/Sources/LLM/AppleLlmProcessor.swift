import Foundation
import FoundationModels

/// On-device LLM using Apple's LanguageModelSession (macOS 26+ / iOS 26+).
///
/// Replaces the FFI bridge pattern: no @_cdecl, no Unmanaged pointers,
/// no C callbacks. Just `await session.respond(to:)`.
public actor AppleLlmProcessor: LlmProcessor {
    private let promptManager = PromptManager()

    public init() {}

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        guard SystemLanguageModel.default.isAvailable else {
            throw MurmurError.llm("Apple Language Model is not available on this device")
        }

        let (instructions, prompt) = promptManager.buildPrompt(for: task)
        let start = ContinuousClock.now

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let text = String(response.content)

        let elapsed = start.duration(to: .now)
        let ms = UInt64(elapsed.components.seconds * 1000)
            + UInt64(elapsed.components.attoseconds / 1_000_000_000_000_000)

        return ProcessingOutput(text: text, processingTimeMs: ms)
    }

    public func healthCheck() async -> Bool {
        SystemLanguageModel.default.isAvailable
    }
}
