import Foundation
import Testing
@testable import MurmurKit

@Suite("ElevenLabsLanguages")
struct ElevenLabsLanguagesTests {
    @Test("Known mappings return correct ISO 639-3 codes")
    func knownMappings() {
        #expect(ElevenLabsLanguages.iso639_3(for: "en") == "eng")
        #expect(ElevenLabsLanguages.iso639_3(for: "zh") == "cmn")
        #expect(ElevenLabsLanguages.iso639_3(for: "ja") == "jpn")
        #expect(ElevenLabsLanguages.iso639_3(for: "ko") == "kor")
        #expect(ElevenLabsLanguages.iso639_3(for: "es") == "spa")
        #expect(ElevenLabsLanguages.iso639_3(for: "fr") == "fra")
        #expect(ElevenLabsLanguages.iso639_3(for: "de") == "deu")
    }

    @Test("Auto passes through as auto")
    func autoPassthrough() {
        #expect(ElevenLabsLanguages.iso639_3(for: "auto") == "auto")
    }

    @Test("Unknown code returns nil")
    func unknownCode() {
        #expect(ElevenLabsLanguages.iso639_3(for: "xx") == nil)
        #expect(ElevenLabsLanguages.iso639_3(for: "") == nil)
    }

    @Test("All entries have unique IDs")
    func uniqueIds() {
        let ids = ElevenLabsLanguages.all.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test("Language list contains expected count")
    func expectedCount() {
        // 94 languages + 1 auto-detect = 95
        #expect(ElevenLabsLanguages.all.count == 95)
    }
}
