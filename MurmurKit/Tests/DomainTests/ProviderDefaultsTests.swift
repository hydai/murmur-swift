import Foundation
import Testing
@testable import MurmurKit

@Suite("ProviderDefaults")
struct ProviderDefaultsTests {
    @Test("Every LLM processor type has a defined default model")
    func everyProcessorHasDefault() {
        for processor in LlmProcessorType.allCases {
            let model = ProviderDefaults.defaultModel(for: processor)
            switch processor {
            case .appleLlm:
                #expect(model.isEmpty, "Apple LLM intentionally has no model")
            default:
                #expect(!model.isEmpty, "\(processor) is missing a default model")
            }
        }
    }

    @Test("Model defaults match the Rust upstream choices")
    func defaultsMatchUpstream() {
        #expect(ProviderDefaults.defaultModel(for: .gemini)       == "gemini-3-flash-preview")
        #expect(ProviderDefaults.defaultModel(for: .copilot)      == "gpt-5-mini")
        #expect(ProviderDefaults.defaultModel(for: .openAILlm)    == "gpt-4o-mini")
        #expect(ProviderDefaults.defaultModel(for: .claude)       == "claude-sonnet-4-20250514")
        #expect(ProviderDefaults.defaultModel(for: .geminiApi)    == "gemini-2.0-flash")
        #expect(ProviderDefaults.defaultModel(for: .customOpenAI) == "gpt-4o-mini")
    }

    @Test("STT defaults match the Rust upstream choices")
    func sttDefaultsMatchUpstream() {
        #expect(ProviderDefaults.elevenLabsModel == "scribe_v2_realtime")
        #expect(ProviderDefaults.groqSttModel    == "whisper-large-v3-turbo")
        #expect(ProviderDefaults.openAISttModel  == "whisper-1")
        #expect(ProviderDefaults.customSttModel  == "whisper-1")
    }

    @Test("API-key constants use snake_case identifiers")
    func apiKeyConstantsAreSnakeCase() {
        #expect(ProviderDefaults.ApiKey.elevenLabs   == "elevenlabs")
        #expect(ProviderDefaults.ApiKey.openAI       == "openai")
        #expect(ProviderDefaults.ApiKey.groq         == "groq")
        #expect(ProviderDefaults.ApiKey.anthropic    == "anthropic")
        #expect(ProviderDefaults.ApiKey.googleAI     == "google_ai")
        #expect(ProviderDefaults.ApiKey.customOpenAI == "custom_openai")
        #expect(ProviderDefaults.ApiKey.customStt    == "custom_stt")
        #expect(ProviderDefaults.ApiKey.openAILlm    == "openai_llm")
    }
}
