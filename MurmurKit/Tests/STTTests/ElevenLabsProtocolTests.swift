import Foundation
import Testing
@testable import MurmurKit

@Suite("ElevenLabs protocol")
struct ElevenLabsProtocolTests {
    @Test("URL omits language_code when language is nil")
    func urlOmitsLanguageWhenNil() {
        let url = ElevenLabsProvider.buildURL(model: "scribe_v2_realtime", language: nil)
        let str = url.absoluteString
        #expect(str.hasPrefix("wss://api.elevenlabs.io/v1/speech-to-text/realtime"))
        #expect(str.contains("model_id=scribe_v2_realtime"))
        #expect(str.contains("audio_format=pcm_16000"))
        #expect(!str.contains("language_code"))
    }

    @Test("URL omits language_code when language is auto")
    func urlOmitsLanguageWhenAuto() {
        let url = ElevenLabsProvider.buildURL(model: "scribe_v2_realtime", language: "auto")
        #expect(!url.absoluteString.contains("language_code"))
    }

    @Test("URL includes language_code when explicit")
    func urlIncludesLanguageWhenExplicit() {
        let url = ElevenLabsProvider.buildURL(model: "scribe_v2_realtime", language: "eng")
        #expect(url.absoluteString.contains("language_code=eng"))
    }

    @Test("URL uses configured model")
    func urlUsesConfiguredModel() {
        let url = ElevenLabsProvider.buildURL(model: "scribe_v1", language: nil)
        #expect(url.absoluteString.contains("model_id=scribe_v1"))
    }

    @Test("PCM encoding is little-endian and base64")
    func pcmEncoding() {
        // 0x0001 little-endian = bytes [0x01, 0x00]
        // 0xFF7F little-endian = bytes [0x7F, 0xFF]  (Int16: 32767)
        // 0x0080 little-endian = bytes [0x80, 0x00]  (Int16: 128)
        let samples: [Int16] = [1, 32767, 128]
        let expectedBytes: [UInt8] = [0x01, 0x00, 0xFF, 0x7F, 0x80, 0x00]
        let expectedBase64 = Data(expectedBytes).base64EncodedString()
        #expect(ElevenLabsProvider.encodePCMBase64(samples) == expectedBase64)
    }

    @Test("PCM encoding handles negative samples")
    func pcmEncodingNegative() {
        // -1 (0xFFFF) little-endian = bytes [0xFF, 0xFF]
        // -32768 (0x8000) little-endian = bytes [0x00, 0x80]
        let samples: [Int16] = [-1, -32768]
        let expectedBytes: [UInt8] = [0xFF, 0xFF, 0x00, 0x80]
        let expectedBase64 = Data(expectedBytes).base64EncodedString()
        #expect(ElevenLabsProvider.encodePCMBase64(samples) == expectedBase64)
    }

    @Test("PCM encoding of empty samples produces empty base64")
    func pcmEncodingEmpty() {
        #expect(ElevenLabsProvider.encodePCMBase64([]) == "")
    }

    @Test("Provider constructs with defaults")
    func providerConstructsWithDefaults() async {
        let provider = ElevenLabsProvider(apiKey: "test")
        _ = provider.events  // stream available
    }

    @Test("Provider constructs with overrides")
    func providerConstructsWithOverrides() async {
        let provider = ElevenLabsProvider(
            apiKey: "test",
            model: "scribe_v2_realtime",
            languageCode: "jpn",
            reconnectConfig: .init(maxRetries: 5, baseDelayMs: 500, maxDelayMs: 10_000)
        )
        _ = provider.events
    }
}
