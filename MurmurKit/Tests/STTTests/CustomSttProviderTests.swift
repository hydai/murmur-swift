import Foundation
import Testing
@testable import MurmurKit

@Suite("CustomSttProvider")
struct CustomSttProviderTests {
    @Test("Construction with default parameters")
    func defaultConstruction() async {
        let provider = CustomSttProvider()
        // Verify it produces an event stream (basic construction test)
        let events = provider.events
        _ = events  // stream exists
    }

    @Test("Construction with custom parameters")
    func customConstruction() async {
        let provider = CustomSttProvider(
            apiKey: "test-key",
            model: "large-v3",
            baseURL: "http://custom:9000",
            language: "zh"
        )
        let events = provider.events
        _ = events
    }

    @Test("Construction with nil API key")
    func nilApiKeyConstruction() async {
        let provider = CustomSttProvider(
            apiKey: nil,
            model: "whisper-1",
            baseURL: "http://localhost:8080"
        )
        let events = provider.events
        _ = events
    }
}
