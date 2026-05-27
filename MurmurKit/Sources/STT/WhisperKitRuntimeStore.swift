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

/// Runtime-level diagnostics for WhisperKit model loading and transcription.
public enum WhisperKitRuntimeMetric: Sendable, Equatable {
    case cacheHit(key: WhisperKitRuntimeKey)
    case awaitingInFlightLoad(key: WhisperKitRuntimeKey)
    case downloadStarted(key: WhisperKitRuntimeKey)
    case downloadFinished(key: WhisperKitRuntimeKey, modelFolder: String, durationMs: UInt64)
    case downloadFailed(key: WhisperKitRuntimeKey, durationMs: UInt64, message: String)
    case loadStarted(key: WhisperKitRuntimeKey, modelFolder: String, prewarm: Bool)
    case loadFinished(key: WhisperKitRuntimeKey, durationMs: UInt64)
    case loadFailed(key: WhisperKitRuntimeKey, durationMs: UInt64, message: String)
    case transcriptionStarted(key: WhisperKitRuntimeKey, sampleCount: Int, clipStartSeconds: Float?)
    case transcriptionFinished(key: WhisperKitRuntimeKey, segmentCount: Int, durationMs: UInt64)
    case transcriptionFailed(key: WhisperKitRuntimeKey, durationMs: UInt64, message: String)
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
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in },
        onMetric: @escaping @Sendable (WhisperKitRuntimeMetric) -> Void = { _ in }
    ) async throws {
        _ = try await runtime(for: config, onStatus: onStatus, onMetric: onMetric)
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
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in },
        onMetric: @escaping @Sendable (WhisperKitRuntimeMetric) -> Void = { _ in }
    ) async throws -> String {
        let key = WhisperKitRuntimeKey(config: config)
        let box = try await runtime(for: config, onStatus: onStatus, onMetric: onMetric)

        await acquire(key)
        defer { release(key) }

        let options = Self.decodingOptions(language: language)
        let startedAt = Date()
        onMetric(.transcriptionStarted(key: key, sampleCount: samples.count, clipStartSeconds: nil))
        do {
            let results = try await box.pipeline.transcribe(
                audioArray: samples,
                decodeOptions: options
            )
            onMetric(.transcriptionFinished(
                key: key,
                segmentCount: results.flatMap(\.segments).count,
                durationMs: Self.elapsedMilliseconds(since: startedAt)
            ))
            return results
                .map(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        } catch {
            onMetric(.transcriptionFailed(
                key: key,
                durationMs: Self.elapsedMilliseconds(since: startedAt),
                message: error.localizedDescription
            ))
            throw error
        }
    }

    func transcribeSegments(
        samples: [Float],
        config: WhisperKitSttConfig,
        language: String?,
        clipStartSeconds: Float? = nil,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void = { _ in },
        onMetric: @escaping @Sendable (WhisperKitRuntimeMetric) -> Void = { _ in }
    ) async throws -> [WhisperKitTranscriptSegment] {
        let key = WhisperKitRuntimeKey(config: config)
        let box = try await runtime(for: config, onStatus: onStatus, onMetric: onMetric)

        await acquire(key)
        defer { release(key) }

        let options = Self.decodingOptions(language: language, clipStartSeconds: clipStartSeconds)

        let startedAt = Date()
        onMetric(.transcriptionStarted(
            key: key,
            sampleCount: samples.count,
            clipStartSeconds: clipStartSeconds
        ))
        do {
            let results = try await box.pipeline.transcribe(
                audioArray: samples,
                decodeOptions: options
            )
            let segments = results
                .flatMap(\.segments)
                .map {
                    WhisperKitTranscriptSegment(
                        text: $0.text,
                        start: $0.start,
                        end: $0.end
                    )
                }
            onMetric(.transcriptionFinished(
                key: key,
                segmentCount: segments.count,
                durationMs: Self.elapsedMilliseconds(since: startedAt)
            ))
            return segments
        } catch {
            onMetric(.transcriptionFailed(
                key: key,
                durationMs: Self.elapsedMilliseconds(since: startedAt),
                message: error.localizedDescription
            ))
            throw error
        }
    }

    func resetForTesting() {
        entries.removeAll()
        busyKeys.removeAll()
        waiters.removeAll()
    }

    private func runtime(
        for config: WhisperKitSttConfig,
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void,
        onMetric: @escaping @Sendable (WhisperKitRuntimeMetric) -> Void
    ) async throws -> RuntimeBox {
        let key = WhisperKitRuntimeKey(config: config)

        if let box = entries[key]?.box {
            onStatus(.ready)
            onMetric(.cacheHit(key: key))
            return box
        }

        if let task = entries[key]?.loadTask {
            onStatus(entries[key]?.status ?? .loading)
            onMetric(.awaitingInFlightLoad(key: key))
            return try await finish(task, for: key, onStatus: onStatus)
        }

        let initialStatus: WhisperKitModelStatus = key.modelFolder.isEmpty
            ? .downloading(0)
            : (config.prewarm ? .prewarming : .loading)
        entries[key] = Entry(status: initialStatus)
        onStatus(initialStatus)

        let task = Task {
            try await Self.makeRuntime(for: config, key: key, onStatus: { [weak self] status in
                Task { await self?.setStatus(status, for: key) }
                onStatus(status)
            }, onMetric: onMetric)
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
        onStatus: @escaping @Sendable (WhisperKitModelStatus) -> Void,
        onMetric: @escaping @Sendable (WhisperKitRuntimeMetric) -> Void
    ) async throws -> RuntimeBox {
        let modelFolder: String
        if key.modelFolder.isEmpty {
            onStatus(.downloading(0))
            let startedAt = Date()
            onMetric(.downloadStarted(key: key))
            do {
                let downloaded = try await WhisperKit.download(
                    variant: key.model,
                    from: key.modelRepo
                ) { progress in
                    onStatus(.downloading(Self.clamped(progress.fractionCompleted)))
                }
                modelFolder = downloaded.path
                onMetric(.downloadFinished(
                    key: key,
                    modelFolder: modelFolder,
                    durationMs: Self.elapsedMilliseconds(since: startedAt)
                ))
            } catch {
                onMetric(.downloadFailed(
                    key: key,
                    durationMs: Self.elapsedMilliseconds(since: startedAt),
                    message: error.localizedDescription
                ))
                throw error
            }
        } else {
            modelFolder = key.modelFolder
        }

        onStatus(config.prewarm ? .prewarming : .loading)
        let loadStartedAt = Date()
        onMetric(.loadStarted(key: key, modelFolder: modelFolder, prewarm: config.prewarm))

        let nativeConfig = WhisperKitConfig(
            model: key.model,
            modelRepo: key.modelRepo,
            modelFolder: modelFolder,
            verbose: false,
            prewarm: config.prewarm,
            load: true,
            download: false
        )
        do {
            let box = RuntimeBox(try await WhisperKit(nativeConfig))
            onMetric(.loadFinished(
                key: key,
                durationMs: Self.elapsedMilliseconds(since: loadStartedAt)
            ))
            return box
        } catch {
            onMetric(.loadFailed(
                key: key,
                durationMs: Self.elapsedMilliseconds(since: loadStartedAt),
                message: error.localizedDescription
            ))
            throw error
        }
    }

    private static func clamped(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }

    private static func elapsedMilliseconds(since start: Date) -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince(start) * 1000))
    }

    private static func decodingOptions(
        language: String?,
        clipStartSeconds: Float? = nil
    ) -> DecodingOptions {
        DecodingOptions(
            language: language,
            detectLanguage: language == nil,
            skipSpecialTokens: true,
            clipTimestamps: clipStartSeconds.map { [$0] } ?? []
        )
    }
}
