import Foundation
import Testing
@testable import MurmurKit

@Suite("HistoryStore")
struct HistoryStoreTests {
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-test-\(UUID().uuidString)")
            .appendingPathComponent("history.json")
    }

    @Test("Add entry and retrieve")
    func addAndRetrieve() async throws {
        let store = HistoryStore(fileURL: makeTempURL())
        let entry = HistoryEntry(rawText: "hello world", processedText: "Hello, world.")
        try await store.add(entry)

        let all = await store.getAll()
        #expect(all.count == 1)
        #expect(all[0].processedText == "Hello, world.")
    }

    @Test("Search filters by text")
    func searchFilters() async throws {
        let store = HistoryStore(fileURL: makeTempURL())
        try await store.add(HistoryEntry(rawText: "apple", processedText: "Apple"))
        try await store.add(HistoryEntry(rawText: "banana", processedText: "Banana"))

        let results = await store.search("ban")
        #expect(results.count == 1)
        #expect(results[0].processedText == "Banana")
    }

    @Test("Delete removes entry")
    func deleteEntry() async throws {
        let store = HistoryStore(fileURL: makeTempURL())
        let entry = HistoryEntry(rawText: "test", processedText: "Test")
        try await store.add(entry)
        try await store.delete(id: entry.id)

        let all = await store.getAll()
        #expect(all.isEmpty)
    }

    @Test("Clear removes all entries")
    func clearEntries() async throws {
        let store = HistoryStore(fileURL: makeTempURL())
        try await store.add(HistoryEntry(rawText: "a", processedText: "A"))
        try await store.add(HistoryEntry(rawText: "b", processedText: "B"))
        try await store.clear()

        let all = await store.getAll()
        #expect(all.isEmpty)
    }

    @Test("Max entries cap enforced")
    func maxEntriesCap() async throws {
        let store = HistoryStore(fileURL: makeTempURL(), maxEntries: 3)
        for i in 0..<5 {
            try await store.add(HistoryEntry(rawText: "\(i)", processedText: "\(i)"))
        }

        let all = await store.getAll()
        #expect(all.count == 3)
        // Most recent should be first
        #expect(all[0].processedText == "4")
    }

    @Test("Persistence round-trip")
    func persistenceRoundTrip() async throws {
        let url = makeTempURL()
        let store1 = HistoryStore(fileURL: url)
        try await store1.add(HistoryEntry(rawText: "persist", processedText: "Persist"))

        // New instance reads from same file
        let store2 = HistoryStore(fileURL: url)
        try await store2.load()
        let all = await store2.getAll()
        #expect(all.count == 1)
        #expect(all[0].processedText == "Persist")
    }
}
