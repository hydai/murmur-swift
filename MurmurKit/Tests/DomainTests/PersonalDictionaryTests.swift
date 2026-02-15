import Foundation
import Testing
@testable import MurmurKit

@Suite("PersonalDictionary")
struct PersonalDictionaryTests {

    // MARK: - DictionaryEntry

    @Test("DictionaryEntry round-trips through JSON")
    func entryRoundTrip() throws {
        let entry = DictionaryEntry(term: "SwiftUI", alias: "SUI", description: "Apple's UI framework")

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoded = try JSONDecoder().decode(DictionaryEntry.self, from: data)

        #expect(decoded.term == "SwiftUI")
        #expect(decoded.alias == "SUI")
        #expect(decoded.description == "Apple's UI framework")
        #expect(decoded.id == entry.id)
    }

    @Test("DictionaryEntry with nil alias and description")
    func entryWithNils() throws {
        let entry = DictionaryEntry(term: "macOS")

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(DictionaryEntry.self, from: data)

        #expect(decoded.term == "macOS")
        #expect(decoded.alias == nil)
        #expect(decoded.description == nil)
    }

    // MARK: - Backward Compatibility

    @Test("JSON with only terms decodes with empty entries")
    func backwardCompat() throws {
        let json = """
        {"terms": ["SwiftUI", "macOS"]}
        """
        let dict = try JSONDecoder().decode(PersonalDictionary.self, from: json.data(using: .utf8)!)

        #expect(dict.terms == ["SwiftUI", "macOS"])
        #expect(dict.entries.isEmpty)
    }

    @Test("Full JSON with both terms and entries decodes correctly")
    func fullDecode() throws {
        let json = """
        {
            "terms": ["legacy"],
            "entries": [
                {"id": "12345678-1234-1234-1234-123456789012", "term": "SwiftUI", "alias": "SUI", "description": "UI framework"}
            ]
        }
        """
        let dict = try JSONDecoder().decode(PersonalDictionary.self, from: json.data(using: .utf8)!)

        #expect(dict.terms == ["legacy"])
        #expect(dict.entries.count == 1)
        #expect(dict.entries[0].term == "SwiftUI")
        #expect(dict.entries[0].alias == "SUI")
    }

    // MARK: - allTermStrings

    @Test("allTermStrings merges legacy terms and entry terms/aliases")
    func allTermStrings() {
        let dict = PersonalDictionary(
            terms: ["legacy1", "legacy2"],
            entries: [
                DictionaryEntry(term: "SwiftUI", alias: "SUI"),
                DictionaryEntry(term: "legacy1"),  // duplicate with legacy
                DictionaryEntry(term: "macOS", alias: nil),
            ]
        )

        let all = dict.allTermStrings
        #expect(all.contains("legacy1"))
        #expect(all.contains("legacy2"))
        #expect(all.contains("SwiftUI"))
        #expect(all.contains("SUI"))
        #expect(all.contains("macOS"))
        // "legacy1" should not be duplicated
        #expect(all.filter { $0 == "legacy1" }.count == 1)
    }

    @Test("allTermStrings with empty dictionary")
    func allTermStringsEmpty() {
        let dict = PersonalDictionary()
        #expect(dict.allTermStrings.isEmpty)
    }

    // MARK: - Search

    @Test("Search by term (case-insensitive)")
    func searchByTerm() {
        let dict = PersonalDictionary(entries: [
            DictionaryEntry(term: "SwiftUI"),
            DictionaryEntry(term: "macOS"),
        ])

        let results = dict.search("swift")
        #expect(results.count == 1)
        #expect(results[0].term == "SwiftUI")
    }

    @Test("Search by alias")
    func searchByAlias() {
        let dict = PersonalDictionary(entries: [
            DictionaryEntry(term: "SwiftUI", alias: "SUI"),
            DictionaryEntry(term: "macOS"),
        ])

        let results = dict.search("sui")
        #expect(results.count == 1)
        #expect(results[0].term == "SwiftUI")
    }

    @Test("Search by description")
    func searchByDescription() {
        let dict = PersonalDictionary(entries: [
            DictionaryEntry(term: "SwiftUI", description: "Apple UI framework"),
            DictionaryEntry(term: "macOS", description: "Desktop OS"),
        ])

        let results = dict.search("framework")
        #expect(results.count == 1)
        #expect(results[0].term == "SwiftUI")
    }

    @Test("Search with no matches returns empty")
    func searchNoMatch() {
        let dict = PersonalDictionary(entries: [
            DictionaryEntry(term: "SwiftUI"),
        ])

        let results = dict.search("android")
        #expect(results.isEmpty)
    }
}
