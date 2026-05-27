import Foundation
import Testing
@testable import MurmurKit

@Suite("WhisperKit cache deletion integration")
struct WhisperKitCacheDeletionIntegrationTests {
    @Test("Downloaded remote model cache can be detected and deleted")
    func downloadedRemoteModelCacheCanBeDeleted() async throws {
        guard ProcessInfo.processInfo.environment["MURMUR_RUN_WHISPERKIT_CACHE_E2E"] == "1" else {
            return
        }

        let previousHome = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"]
        let tempHome = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmur-whisperkit-cache-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent("Documents"),
            withIntermediateDirectories: true
        )
        setenv("CFFIXED_USER_HOME", tempHome.path, 1)
        defer {
            if let previousHome {
                setenv("CFFIXED_USER_HOME", previousHome, 1)
            } else {
                unsetenv("CFFIXED_USER_HOME")
            }
            try? FileManager.default.removeItem(at: tempHome)
        }

        let config = WhisperKitSttConfig(
            model: "tiny",
            modelRepo: ProviderDefaults.whisperKitModelRepo,
            modelFolder: "",
            prewarm: false
        )
        let manager = WhisperKitModelManager()

        let initialInventory = await manager.inventory(for: config)
        guard case .notCached(let repoPath) = initialInventory.storageStatus else {
            Issue.record("Expected a clean temporary cache before download, got \(initialInventory.storageStatus)")
            return
        }

        try await WhisperKitRuntimeStore.shared.preload(config: config) { status in
            print("[WhisperKit cache E2E] status=\(status)")
        }

        let cachedInventory = await manager.inventory(for: config)
        guard case .remoteCached(let cachedPath, let sizeBytes) = cachedInventory.storageStatus else {
            Issue.record("Expected downloaded model to be detected as cached, got \(cachedInventory.storageStatus)")
            return
        }
        #expect(resolvedPath(cachedPath).hasPrefix(resolvedPath(repoPath)))
        #expect(cachedPath.contains("tiny"))
        #expect(sizeBytes > 0)

        let sentinel = URL(fileURLWithPath: repoPath).appendingPathComponent("sentinel-other-model")
        try FileManager.default.createDirectory(at: sentinel, withIntermediateDirectories: true)

        try await manager.deleteCachedModel(for: config)

        #expect(!FileManager.default.fileExists(atPath: cachedPath))
        #expect(FileManager.default.fileExists(atPath: sentinel.path))

        let deletedInventory = await manager.inventory(for: config)
        guard case .notCached = deletedInventory.storageStatus else {
            Issue.record("Expected model cache to be absent after delete, got \(deletedInventory.storageStatus)")
            return
        }
    }

    private func resolvedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}
