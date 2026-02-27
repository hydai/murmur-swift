import Foundation
import Testing
@testable import MurmurKit

@Suite("AppConfig")
struct AppConfigTests {
    @Test("Default config has expected values")
    func defaultConfig() {
        let config = AppConfig()
        #expect(config.sttProvider == .appleStt)
        #expect(config.llmProcessor == .appleLlm)
        #expect(config.outputMode == .clipboard)
        #expect(config.hotkey == "Ctrl+`")
        #expect(config.appleSttLocale == "auto")
        #expect(config.sttLanguage == "auto")
        #expect(config.llmModel == "")
        #expect(config.httpLlmConfig.customBaseUrl == "http://localhost:11434/v1")
        #expect(config.httpLlmConfig.customDisplayName == "Ollama")
        #expect(config.httpSttConfig.customBaseUrl == "http://localhost:8080")
        #expect(config.httpSttConfig.customDisplayName == "Custom STT")
        #expect(config.httpSttConfig.customModel == "whisper-1")
        #expect(config.apiKeys.isEmpty)
        #expect(config.personalDictionary.terms.isEmpty)
        #expect(config.personalDictionary.entries.isEmpty)
    }

    @Test("Config round-trips through JSON")
    func jsonRoundTrip() throws {
        var config = AppConfig()
        config.sttProvider = .elevenLabs
        config.apiKeys["elevenlabs"] = "test-key"
        config.outputMode = .both
        config.personalDictionary.terms = ["SwiftUI", "macOS"]
        config.sttLanguage = "zh"
        config.llmModel = "gpt-4o"
        config.llmProcessor = .openAILlm
        config.httpLlmConfig = HttpLlmConfig(customBaseUrl: "http://custom:8080/v1", customDisplayName: "Custom")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(AppConfig.self, from: data)

        #expect(decoded.sttProvider == .elevenLabs)
        #expect(decoded.apiKeys["elevenlabs"] == "test-key")
        #expect(decoded.outputMode == .both)
        #expect(decoded.personalDictionary.terms == ["SwiftUI", "macOS"])
        #expect(decoded.sttLanguage == "zh")
        #expect(decoded.llmModel == "gpt-4o")
        #expect(decoded.llmProcessor == .openAILlm)
        #expect(decoded.httpLlmConfig.customBaseUrl == "http://custom:8080/v1")
        #expect(decoded.httpLlmConfig.customDisplayName == "Custom")
    }

    @Test("Custom STT config round-trips through JSON")
    func customSttConfigRoundTrip() throws {
        var config = AppConfig()
        config.sttProvider = .customStt
        config.apiKeys["custom_stt"] = "test-stt-key"
        config.httpSttConfig = HttpSttConfig(
            customBaseUrl: "http://whisper:9000",
            customDisplayName: "My Whisper",
            customModel: "large-v3"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(AppConfig.self, from: data)

        #expect(decoded.sttProvider == .customStt)
        #expect(decoded.apiKeys["custom_stt"] == "test-stt-key")
        #expect(decoded.httpSttConfig.customBaseUrl == "http://whisper:9000")
        #expect(decoded.httpSttConfig.customDisplayName == "My Whisper")
        #expect(decoded.httpSttConfig.customModel == "large-v3")
    }

    @Test("New LlmProcessorType cases round-trip through JSON")
    func newLlmTypesRoundTrip() throws {
        let types: [LlmProcessorType] = [.openAILlm, .claude, .geminiApi, .customOpenAI]
        for type in types {
            var config = AppConfig()
            config.llmProcessor = type

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(config)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(AppConfig.self, from: data)

            #expect(decoded.llmProcessor == type)
        }
    }

    @Test("Backward compatibility: JSON without sttLanguage decodes with default")
    func backwardCompatibility() throws {
        // Simulates a config file saved before sttLanguage/llmModel/httpLlmConfig were added
        let json = """
        {
            "stt_provider": "appleStt",
            "api_keys": {},
            "hotkey": "Ctrl+`",
            "llm_processor": "appleLlm",
            "output_mode": "clipboard",
            "ui_preferences": {"opacity": 0.9, "show_waveform": true, "theme": "dark"},
            "apple_stt_locale": "auto",
            "personal_dictionary": {"terms": []}
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let config = try decoder.decode(AppConfig.self, from: json.data(using: .utf8)!)

        #expect(config.sttLanguage == "auto")
        #expect(config.sttProvider == .appleStt)
        #expect(config.appleSttLocale == "auto")
        #expect(config.llmModel == "")
        #expect(config.httpLlmConfig.customBaseUrl == "http://localhost:11434/v1")
        #expect(config.httpSttConfig.customBaseUrl == "http://localhost:8080")
        #expect(config.httpSttConfig.customModel == "whisper-1")
        #expect(config.personalDictionary.entries.isEmpty)
    }
}
