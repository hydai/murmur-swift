import Foundation

public struct WhisperKitDiagnosticsSnapshot: Sendable, Equatable {
    public private(set) var updatedAt: Date?
    public private(set) var model: String?
    public private(set) var modelRepo: String?
    public private(set) var usesCustomModelFolder = false
    public private(set) var sessionStartedAt: Date?
    public private(set) var intervalMs: Int?
    public private(set) var minimumSamples: Int?
    public private(set) var requiredSegmentsForConfirmation: Int?
    public private(set) var totalSamples: Int?
    public private(set) var firstPartialLatencyMs: UInt64?
    public private(set) var lastRealtimeDurationMs: UInt64?
    public private(set) var lastRealtimeSampleCount: Int?
    public private(set) var lastRealtimeSegmentCount: Int?
    public private(set) var lastFinalDurationMs: UInt64?
    public private(set) var lastFinalSegmentCount: Int?
    public private(set) var lastDownloadDurationMs: UInt64?
    public private(set) var lastLoadDurationMs: UInt64?
    public private(set) var lastNativeTranscriptionDurationMs: UInt64?
    public private(set) var lastNativeTranscriptionSampleCount: Int?
    public private(set) var cacheHitCount = 0
    public private(set) var partialEventCount = 0
    public private(set) var committedEventCount = 0
    public private(set) var errorEventCount = 0
    public private(set) var lastError: String?
    public private(set) var recentEvents: [WhisperKitDiagnosticsEvent] = []

    public init() {}

    public var hasData: Bool {
        updatedAt != nil
    }

    public var modelText: String {
        guard let model else { return "No model yet" }
        return model
    }

    public var modelSourceText: String {
        guard hasData else { return "No source yet" }
        return usesCustomModelFolder ? "Local folder" : "Model cache"
    }

    public mutating func apply(_ metric: WhisperKitProviderMetric) {
        touch()

        switch metric {
        case .sessionStarted(
            let model,
            let intervalMs,
            let minimumSamples,
            let requiredSegmentsForConfirmation
        ):
            self.model = model
            self.intervalMs = intervalMs
            self.minimumSamples = minimumSamples
            self.requiredSegmentsForConfirmation = requiredSegmentsForConfirmation
            sessionStartedAt = updatedAt
            firstPartialLatencyMs = nil
            partialEventCount = 0
            committedEventCount = 0
            errorEventCount = 0
            lastError = nil
            append("Session started", detail: "\(intervalMs) ms interval")

        case .audioReceived(let totalSamples, let chunkSamples, _):
            self.totalSamples = totalSamples
            append("Audio received", detail: "\(chunkSamples) samples")

        case .realtimePassStarted(let sampleCount, _):
            lastRealtimeSampleCount = sampleCount
            append("Realtime pass started", detail: "\(sampleCount) samples")

        case .realtimePassFinished(let sampleCount, let segmentCount, _, let durationMs):
            lastRealtimeSampleCount = sampleCount
            lastRealtimeSegmentCount = segmentCount
            lastRealtimeDurationMs = durationMs
            append("Realtime pass finished", detail: "\(durationMs) ms")

        case .realtimePassFailed(let sampleCount, let durationMs, let message):
            lastRealtimeSampleCount = sampleCount
            lastRealtimeDurationMs = durationMs
            recordError(message)
            append("Realtime pass failed", detail: "\(durationMs) ms", level: .error)

        case .realtimePassCancelled(let sampleCount, let durationMs):
            lastRealtimeSampleCount = sampleCount
            lastRealtimeDurationMs = durationMs
            append("Realtime pass cancelled", detail: "\(durationMs) ms")

        case .firstPartialLatency(let durationMs):
            firstPartialLatencyMs = durationMs
            append("First partial", detail: "\(durationMs) ms")

        case .finalPassStarted(let sampleCount, _):
            totalSamples = sampleCount
            append("Final pass started", detail: "\(sampleCount) samples")

        case .finalPassFinished(let segmentCount, let emittedEventCount, let durationMs):
            lastFinalSegmentCount = segmentCount
            lastFinalDurationMs = durationMs
            append("Final pass finished", detail: "\(durationMs) ms, \(emittedEventCount) events")

        case .finalPassFailed(let durationMs, let message):
            lastFinalDurationMs = durationMs
            recordError(message)
            append("Final pass failed", detail: "\(durationMs) ms", level: .error)

        case .runtime(let runtimeMetric):
            apply(runtimeMetric)

        case .sessionFinished(let totalSamples, let partialEvents, let committedEvents, let errorEvents):
            self.totalSamples = totalSamples
            partialEventCount = partialEvents
            committedEventCount = committedEvents
            errorEventCount = errorEvents
            append("Session finished", detail: "\(committedEvents) committed, \(partialEvents) partial")
        }
    }

    public mutating func apply(_ metric: WhisperKitRuntimeMetric) {
        touch()

        switch metric {
        case .cacheHit(let key):
            apply(key)
            cacheHitCount += 1
            append("Runtime cache hit", detail: key.model)

        case .awaitingInFlightLoad(let key):
            apply(key)
            append("Awaiting model load", detail: key.model)

        case .downloadStarted(let key):
            apply(key)
            append("Download started", detail: key.model)

        case .downloadFinished(let key, _, let durationMs):
            apply(key)
            lastDownloadDurationMs = durationMs
            append("Download finished", detail: "\(durationMs) ms")

        case .downloadFailed(let key, let durationMs, let message):
            apply(key)
            lastDownloadDurationMs = durationMs
            recordError(message)
            append("Download failed", detail: "\(durationMs) ms", level: .error)

        case .loadStarted(let key, _, let prewarm):
            apply(key)
            append(prewarm ? "Prewarm started" : "Load started", detail: key.model)

        case .loadFinished(let key, let durationMs):
            apply(key)
            lastLoadDurationMs = durationMs
            append("Load finished", detail: "\(durationMs) ms")

        case .loadFailed(let key, let durationMs, let message):
            apply(key)
            lastLoadDurationMs = durationMs
            recordError(message)
            append("Load failed", detail: "\(durationMs) ms", level: .error)

        case .transcriptionStarted(let key, let sampleCount, _):
            apply(key)
            lastNativeTranscriptionSampleCount = sampleCount
            append("Native transcription started", detail: "\(sampleCount) samples")

        case .transcriptionFinished(let key, _, let durationMs):
            apply(key)
            lastNativeTranscriptionDurationMs = durationMs
            append("Native transcription finished", detail: "\(durationMs) ms")

        case .transcriptionFailed(let key, let durationMs, let message):
            apply(key)
            lastNativeTranscriptionDurationMs = durationMs
            recordError(message)
            append("Native transcription failed", detail: "\(durationMs) ms", level: .error)
        }
    }

    private mutating func apply(_ key: WhisperKitRuntimeKey) {
        model = key.model
        modelRepo = key.modelRepo
        usesCustomModelFolder = !key.modelFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private mutating func touch() {
        updatedAt = Date()
    }

    private mutating func recordError(_ message: String) {
        lastError = message
        errorEventCount += 1
    }

    private mutating func append(
        _ title: String,
        detail: String,
        level: WhisperKitDiagnosticsEvent.Level = .info
    ) {
        recentEvents.insert(WhisperKitDiagnosticsEvent(
            timestamp: updatedAt ?? Date(),
            title: title,
            detail: detail,
            level: level
        ), at: 0)
        if recentEvents.count > 8 {
            recentEvents.removeLast(recentEvents.count - 8)
        }
    }
}

public struct WhisperKitDiagnosticsEvent: Sendable, Equatable, Identifiable {
    public enum Level: Sendable, Equatable {
        case info
        case error
    }

    public let id = UUID()
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let level: Level

    public static func == (lhs: WhisperKitDiagnosticsEvent, rhs: WhisperKitDiagnosticsEvent) -> Bool {
        lhs.id == rhs.id
            && lhs.timestamp == rhs.timestamp
            && lhs.title == rhs.title
            && lhs.detail == rhs.detail
            && lhs.level == rhs.level
    }
}
