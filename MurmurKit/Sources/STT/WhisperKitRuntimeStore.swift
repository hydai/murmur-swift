import Foundation
import WhisperKit

/// User-visible lifecycle state for Murmur's native WhisperKit runtime.
public enum WhisperKitModelStatus: Sendable, Equatable {
    case idle
    case downloading(Double)
    case loading
    case prewarming
    case ready
    case error(String)

    public var isBusy: Bool {
        switch self {
        case .downloading, .loading, .prewarming:
            return true
        case .idle, .ready, .error:
            return false
        }
    }
}

/// Cache key for reusable native WhisperKit runtimes.
public struct WhisperKitRuntimeKey: Sendable, Hashable {
    public let model: String
    public let modelRepo: String
    public let modelFolder: String

    public init(config: WhisperKitSttConfig) {
        self.model = Self.normalized(config.model, fallback: ProviderDefaults.whisperKitSttModel)
        self.modelRepo = Self.normalized(config.modelRepo, fallback: ProviderDefaults.whisperKitModelRepo)
        self.modelFolder = config.modelFolder.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

/// Shared native WhisperKit runtime cache.
///
/// `SttProvider` instances are session-scoped because their event streams are
/// finished at stop time. This actor keeps the expensive native WhisperKit
/// pipeline alive across those short-lived providers.
public actor WhisperKitRuntimeStore {
    public static let shared = WhisperKitRuntimeStore()

    private final class RuntimeBox: @unchecked Sendable {
        let pipeline: WhisperKit

        init(_ pipeline: WhisperKit) {
            self.pipeline = pipeline
        }
    }

    private struct Entry {
        var box: RuntimeBox?
        var loadTask: Task<RuntimeBox, Error>?
        var status: WhisperKitModelStatus

        init(
            box: RuntimeBox? = nil,
            loadTask: Task<RuntimeBox, Error>? = nil,
            status: WhisperKitModelStatus = .idle
        ) {
            self.box = box
            self.loadTask = loadTask
            self.status = status
        }
    }

    private var entries: [WhisperKitRuntimeKey: Entry] = [:]
    private var busyKeys: Set<WhisperKitRuntimeKey> = []
    private var waiters: [WhisperKitRuntimeKey: [CheckedContinuation<Void, Never>]] = [:]

    public init() {}

    public func status(for config: WhisperKitSttConfig) -> WhisperKitModelStatus {
        let key = WhisperKitRuntimeKey(config: config)
        return entries[key]?.status ?? .idle
    }

    public func preload(
        config: WhisperKitSttConfig,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in }
    ) async throws {
        _ = try await runtime(for: config, onStatus: onStatus)
    }

    public func evict(config: WhisperKitSttConfig) async {
        let key = WhisperKitRuntimeKey(config: config)
        let box = entries[key]?.box
        entries[key] = nil
        if let box {
            await box.pipeline.unloadModels()
        }
    }

    public func transcribe(
        samples: [Float],
        config: WhisperKitSttConfig,
        language: String?,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in }
    ) async throws -> String {
        let key = WhisperKitRuntimeKey(config: config)
        let box = try await runtime(for: config, onStatus: onStatus)

        await acquire(key)
        defer { release(key) }

        let options = DecodingOptions(
            language: language,
            detectLanguage: language == nil
        )
        let results = try await box.pipeline.transcribe(
            audioArray: samples,
            decodeOptions: options
        )
        return results
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func transcribeSegments(
        samples: [Float],
        config: WhisperKitSttConfig,
        language: String?,
        clipStartSeconds: Float? = nil,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in }
    ) async throws -> [WhisperKitTranscriptSegment] {
        let key = WhisperKitRuntimeKey(config: config)
        let box = try await runtime(for: config, onStatus: onStatus)

        await acquire(key)
        defer { release(key) }

        var options = DecodingOptions(
            language: language,
            detectLanguage: language == nil
        )
        if let clipStartSeconds {
            options.clipTimestamps = [clipStartSeconds]
        }

        let results = try await box.pipeline.transcribe(
            audioArray: samples,
            decodeOptions: options
        )
        return results
            .flatMap(\.segments)
            .map {
                WhisperKitTranscriptSegment(
                    text: $0.text,
                    start: $0.start,
                    end: $0.end
                )
            }
    }

    func resetForTesting() {
        entries.removeAll()
        busyKeys.removeAll()
        waiters.removeAll()
    }

    private func runtime(
        for config: WhisperKitSttConfig,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void
    ) async throws -> RuntimeBox {
        let key = WhisperKitRuntimeKey(config: config)

        if let box = entries[key]?.box {
            onStatus(.ready)
            return box
        }

        if let task = entries[key]?.loadTask {
            onStatus(entries[key]?.status ?? .loading)
            return try await finish(task, for: key, onStatus: onStatus)
        }

        let initialStatus: WhisperKitModelStatus = key.modelFolder.isEmpty
            ? .downloading(0)
            : (config.prewarm ? .prewarming : .loading)
        entries[key] = Entry(status: initialStatus)
        onStatus(initialStatus)

        let task = Task {
            try await Self.makeRuntime(for: config, key: key) { [weak self] status in
                Task { await self?.setStatus(status, for: key) }
                onStatus(status)
            }
        }
        entries[key] = Entry(loadTask: task, status: initialStatus)

        return try await finish(task, for: key, onStatus: onStatus)
    }

    private func finish(
        _ task: Task<RuntimeBox, Error>,
        for key: WhisperKitRuntimeKey,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void
    ) async throws -> RuntimeBox {
        do {
            let box = try await task.value
            entries[key] = Entry(box: box, status: .ready)
            onStatus(.ready)
            return box
        } catch {
            let status = WhisperKitModelStatus.error(error.localizedDescription)
            entries[key] = Entry(status: status)
            onStatus(status)
            throw error
        }
    }

    private func setStatus(_ status: WhisperKitModelStatus, for key: WhisperKitRuntimeKey) {
        guard var entry = entries[key] else { return }
        if entry.box != nil || entry.loadTask == nil {
            return
        }
        entry.status = status
        entries[key] = entry
    }

    private func acquire(_ key: WhisperKitRuntimeKey) async {
        while busyKeys.contains(key) {
            await withCheckedContinuation { continuation in
                waiters[key, default: []].append(continuation)
            }
        }
        busyKeys.insert(key)
    }

    private func release(_ key: WhisperKitRuntimeKey) {
        busyKeys.remove(key)
        if var keyWaiters = waiters[key], !keyWaiters.isEmpty {
            let next = keyWaiters.removeFirst()
            waiters[key] = keyWaiters.isEmpty ? nil : keyWaiters
            next.resume()
        }
    }

    private static func makeRuntime(
        for config: WhisperKitSttConfig,
        key: WhisperKitRuntimeKey,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void
    ) async throws -> RuntimeBox {
        let modelFolder: String
        if key.modelFolder.isEmpty {
            onStatus(.downloading(0))
            let downloaded = try await WhisperKit.download(
                variant: key.model,
                from: key.modelRepo
            ) { progress in
                onStatus(.downloading(Self.clamped(progress.fractionCompleted)))
            }
            modelFolder = downloaded.path
        } else {
            modelFolder = key.modelFolder
        }

        onStatus(config.prewarm ? .prewarming : .loading)

        let nativeConfig = WhisperKitConfig(
            model: key.model,
            modelRepo: key.modelRepo,
            modelFolder: modelFolder,
            verbose: false,
            prewarm: config.prewarm,
            load: true,
            download: false
        )
        return RuntimeBox(try await WhisperKit(nativeConfig))
    }

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
