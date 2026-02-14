import Foundation
import Testing
@testable import MurmurKit

@Suite("ConfigManager")
struct ConfigManagerTests {
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-test-\(UUID().uuidString)")
            .appendingPathComponent("config.json")
    }

    @Test("Default config loaded when no file exists")
    func defaultConfig() async throws {
        let manager = ConfigManager(fileURL: makeTempURL())
        try await manager.load()
        let config = await manager.getConfig()
        #expect(config.sttProvider == .appleStt)
        #expect(config.llmProcessor == .appleLlm)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() async throws {
        let url = makeTempURL()
        let manager = ConfigManager(fileURL: url)

        try await manager.setConfig(AppConfig(
            sttProvider: .openAI,
            apiKeys: ["openai": "sk-test"],
            outputMode: .both
        ))

        // New instance reads from same file
        let manager2 = ConfigManager(fileURL: url)
        try await manager2.load()
        let config = await manager2.getConfig()
        #expect(config.sttProvider == .openAI)
        #expect(config.apiKeys["openai"] == "sk-test")
        #expect(config.outputMode == .both)
    }

    @Test("Update mutates and persists")
    func updateConfig() async throws {
        let url = makeTempURL()
        let manager = ConfigManager(fileURL: url)

        try await manager.update { config in
            config.hotkey = "Cmd+Shift+M"
        }

        let config = await manager.getConfig()
        #expect(config.hotkey == "Cmd+Shift+M")

        // Verify persistence
        let manager2 = ConfigManager(fileURL: url)
        try await manager2.load()
        let loaded = await manager2.getConfig()
        #expect(loaded.hotkey == "Cmd+Shift+M")
    }
}
