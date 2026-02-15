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
        #expect(config.apiKeys.isEmpty)
        #expect(config.personalDictionary.terms.isEmpty)
    }

    @Test("Config round-trips through JSON")
    func jsonRoundTrip() throws {
        var config = AppConfig()
        config.sttProvider = .elevenLabs
        config.apiKeys["elevenlabs"] = "test-key"
        config.outputMode = .both
        config.personalDictionary.terms = ["SwiftUI", "macOS"]
        config.sttLanguage = "zh"

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
    }

    @Test("Backward compatibility: JSON without sttLanguage decodes with default")
    func backwardCompatibility() throws {
        // Simulates a config file saved before the sttLanguage field was added
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
    }
}
