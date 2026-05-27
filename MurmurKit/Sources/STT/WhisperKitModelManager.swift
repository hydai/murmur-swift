import Foundation
import WhisperKit

public enum WhisperKitModelStorageStatus: Sendable, Equatable {
    case localReady(path: String, sizeBytes: Int64)
    case localMissing(path: String, reason: String)
    case remoteCached(path: String, sizeBytes: Int64)
    case notCached(path: String)

    public var isReady: Bool {
        switch self {
        case .localReady, .remoteCached:
            return true
        case .localMissing, .notCached:
            return false
        }
    }

    public var sizeBytes: Int64? {
        switch self {
        case .localReady(_, let sizeBytes), .remoteCached(_, let sizeBytes):
            return sizeBytes
        case .localMissing, .notCached:
            return nil
        }
    }

    public var path: String {
        switch self {
        case .localReady(let path, _),
             .localMissing(let path, _),
             .remoteCached(let path, _),
             .notCached(let path):
            return path
        }
    }
}

public struct WhisperKitModelInventory: Sendable, Equatable {
    public var selectedModel: String
    public var recommendedModel: String
    public var supportedModels: [String]
    public var knownModels: [String]
    public var storageStatus: WhisperKitModelStorageStatus

    public init(
        selectedModel: String,
        recommendedModel: String,
        supportedModels: [String],
        knownModels: [String],
        storageStatus: WhisperKitModelStorageStatus
    ) {
        self.selectedModel = selectedModel
        self.recommendedModel = recommendedModel
        self.supportedModels = supportedModels
        self.knownModels = knownModels
        self.storageStatus = storageStatus
    }
}

public actor WhisperKitModelManager {
    public init() {}

    public func inventory(for config: WhisperKitSttConfig) async -> WhisperKitModelInventory {
        let catalog = catalog()
        let key = WhisperKitRuntimeKey(config: config)
        return WhisperKitModelInventory(
            selectedModel: key.model,
            recommendedModel: catalog.recommendedModel,
            supportedModels: catalog.supportedModels,
            knownModels: catalog.knownModels,
            storageStatus: storageStatus(for: key)
        )
    }

    public func deleteCachedModel(for config: WhisperKitSttConfig) async throws {
        let key = WhisperKitRuntimeKey(config: config)
        guard key.modelFolder.isEmpty else { return }

        if let modelURL = cachedRemoteModelFolder(for: key) {
            try FileManager.default.removeItem(at: modelURL)
        }
        await WhisperKitRuntimeStore.shared.evict(config: config)
    }

    public static func displaySize(_ bytes: Int64?) -> String {
        guard let bytes else { return "Not cached" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func normalizedModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func catalog() -> (
        recommendedModel: String,
        supportedModels: [String],
        knownModels: [String]
    ) {
        let support = WhisperKit.recommendedModels()
        let supported = orderedUnique(support.supported.map(Self.normalizedModelName))
        let known = orderedUnique(Constants.knownModels.map(Self.normalizedModelName))
        let recommended = Self.normalizedModelName(support.default)
        return (recommended, supported, known)
    }

    private func storageStatus(for key: WhisperKitRuntimeKey) -> WhisperKitModelStorageStatus {
        if !key.modelFolder.isEmpty {
            let url = URL(fileURLWithPath: key.modelFolder)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .localMissing(path: url.path, reason: "Folder does not exist")
            }
            guard hasWhisperModelComponents(in: url) else {
                return .localMissing(path: url.path, reason: "Missing MelSpectrogram, AudioEncoder, or TextDecoder model files")
            }
            return .localReady(path: url.path, sizeBytes: folderSize(at: url))
        }

        let repoURL = remoteRepoLocation(for: key)
        guard let modelURL = cachedRemoteModelFolder(for: key) else {
            return .notCached(path: repoURL.path)
        }
        return .remoteCached(path: modelURL.path, sizeBytes: folderSize(at: modelURL))
    }

    private func cachedRemoteModelFolder(for key: WhisperKitRuntimeKey) -> URL? {
        let repoURL = remoteRepoLocation(for: key)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: repoURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let model = Self.normalizedModelName(key.model)
        return contents.first { url in
            guard isDirectory(url) else { return false }
            let folderName = Self.normalizedModelName(url.lastPathComponent)
            return folderName.contains(model) && hasWhisperModelComponents(in: url)
        }
    }

    private func remoteRepoLocation(for key: WhisperKitRuntimeKey) -> URL {
        let hubApi = HubApiWrapper.shared
        return hubApi.localRepoLocation(HubApiWrapper.Repo(id: key.modelRepo))
    }

    private func hasWhisperModelComponents(in url: URL) -> Bool {
        let names = Set(((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).map {
            $0.components(separatedBy: ".").first ?? $0
        })
        return names.contains("MelSpectrogram")
            && names.contains("AudioEncoder")
            && names.contains("TextDecoder")
    }

    private func folderSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true
            else {
                continue
            }
            size += Int64(values.fileSize ?? 0)
        }
        return size
    }

    private func isDirectory(_ url: URL) -> Bool {
        ((try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory) == true
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !value.isEmpty {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }
}
