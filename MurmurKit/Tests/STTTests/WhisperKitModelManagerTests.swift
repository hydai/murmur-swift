import Foundation
import Testing
@testable import MurmurKit

@Suite("WhisperKitModelManager")
struct WhisperKitModelManagerTests {
    @Test("Normalizes OpenAI Whisper model prefixes for UI choices")
    func normalizesOpenAIWhisperPrefix() {
        #expect(WhisperKitModelManager.normalizedModelName("openai_whisper-base.en") == "base.en")
        #expect(WhisperKitModelManager.normalizedModelName("distil-whisper_distil-large-v3_594MB") == "distil-whisper_distil-large-v3_594MB")
    }

    @Test("Local folder with WhisperKit components is ready")
    func localFolderWithComponentsIsReady() async throws {
        let folder = try makeTempModelFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try makeModelComponents(in: folder)
        let manager = WhisperKitModelManager()
        let inventory = await manager.inventory(for: WhisperKitSttConfig(modelFolder: folder.path))

        guard case .localReady(let path, let sizeBytes) = inventory.storageStatus else {
            Issue.record("Expected localReady, got \(inventory.storageStatus)")
            return
        }
        #expect(path == folder.path)
        #expect(sizeBytes > 0)
        #expect(inventory.recommendedModel.isEmpty == false)
        #expect(inventory.knownModels.contains(ProviderDefaults.whisperKitSttModel))
    }

    @Test("Local folder missing components is invalid")
    func localFolderMissingComponentsIsInvalid() async throws {
        let folder = try makeTempModelFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("MelSpectrogram.mlmodelc"),
            withIntermediateDirectories: true
        )
        let manager = WhisperKitModelManager()
        let inventory = await manager.inventory(for: WhisperKitSttConfig(modelFolder: folder.path))

        guard case .localMissing(let path, let reason) = inventory.storageStatus else {
            Issue.record("Expected localMissing, got \(inventory.storageStatus)")
            return
        }
        #expect(path == folder.path)
        #expect(reason.contains("Missing"))
    }

    @Test("Nil cache size displays as not cached")
    func nilCacheSizeDisplaysAsNotCached() {
        #expect(WhisperKitModelManager.displaySize(nil) == "Not cached")
    }

    private func makeTempModelFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("murmur-whisperkit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func makeModelComponents(in folder: URL) throws {
        for name in ["MelSpectrogram.mlmodelc", "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc"] {
            let component = folder.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: component, withIntermediateDirectories: true)
            let data = Data([0, 1, 2, 3])
            try data.write(to: component.appendingPathComponent("weights.bin"))
        }
    }
}
