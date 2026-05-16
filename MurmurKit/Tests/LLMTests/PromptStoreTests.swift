import Foundation
import Testing
@testable import MurmurKit

@Suite("PromptStore")
struct PromptStoreTests {
    /// Create a temp directory and clean it up after the closure returns.
    private func withTempDir(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PromptStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }

    @Test("loadAll with missing prompts dir returns defaults")
    func loadAllMissingDirReturnsDefaults() throws {
        try withTempDir { dir in
            let set = try PromptStore.loadAll(configDir: dir)
            for name in PromptName.allCases {
                #expect(!set.hasOverride(name))
                #expect(set.get(name) == name.defaultTemplate)
            }
        }
    }

    @Test("save then loadAll round-trips byte-exact")
    func saveThenLoadRoundTrip() throws {
        try withTempDir { dir in
            let content = "# Custom\n\nLine with {placeholder} here.\n"
            try PromptStore.save(.shorten, content: content, in: dir)

            let set = try PromptStore.loadAll(configDir: dir)
            #expect(set.hasOverride(.shorten))
            #expect(set.get(.shorten) == content)
        }
    }

    @Test("reset deletes the override file")
    func resetDeletesOverrideFile() throws {
        try withTempDir { dir in
            try PromptStore.save(.translate, content: "OVERRIDE", in: dir)
            let savedPath = PromptStore.file(for: .translate, in: dir).path
            #expect(FileManager.default.fileExists(atPath: savedPath))

            try PromptStore.reset(.translate, in: dir)
            #expect(!FileManager.default.fileExists(atPath: savedPath))

            let set = try PromptStore.loadAll(configDir: dir)
            #expect(!set.hasOverride(.translate))
        }
    }

    @Test("reset on a missing file is a no-op")
    func resetMissingFileIsNoop() throws {
        try withTempDir { dir in
            // Directory exists but no override file inside it.
            try FileManager.default.createDirectory(
                at: PromptStore.directory(in: dir),
                withIntermediateDirectories: true
            )
            try PromptStore.reset(.postProcess, in: dir)
        }
    }

    @Test("overrides are stored independently per name")
    func overridesAreIndependent() throws {
        try withTempDir { dir in
            try PromptStore.save(.shorten, content: "ONE", in: dir)
            try PromptStore.save(.translate, content: "TWO", in: dir)

            let set = try PromptStore.loadAll(configDir: dir)
            #expect(set.get(.shorten) == "ONE")
            #expect(set.get(.translate) == "TWO")
            #expect(!set.hasOverride(.changeTone))
            #expect(set.get(.changeTone) == PromptName.changeTone.defaultTemplate)
        }
    }

    @Test("save creates the prompts subdirectory")
    func saveCreatesSubdirectory() throws {
        try withTempDir { dir in
            try PromptStore.save(.postProcess, content: "x", in: dir)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: PromptStore.directory(in: dir).path,
                isDirectory: &isDir
            )
            #expect(exists && isDir.boolValue)
        }
    }
}
