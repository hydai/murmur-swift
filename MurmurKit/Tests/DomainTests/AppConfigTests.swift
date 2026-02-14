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
    }
}
