import Foundation
import MurmurKit

@MainActor
final class WhisperKitDiagnosticsStore {
    static let shared = WhisperKitDiagnosticsStore()

    private(set) var snapshot = WhisperKitDiagnosticsSnapshot()

    private init() {}

    func record(_ metric: WhisperKitProviderMetric) {
        snapshot.apply(metric)
    }

    func record(_ metric: WhisperKitRuntimeMetric) {
        snapshot.apply(metric)
    }

    func reset() {
        snapshot = WhisperKitDiagnosticsSnapshot()
    }
}

enum WhisperKitDiagnosticsRecorder {
    static func record(_ metric: WhisperKitProviderMetric) {
        WhisperKitMetricLogger.log(metric)
        Task { @MainActor in
            WhisperKitDiagnosticsStore.shared.record(metric)
        }
    }

    static func record(_ metric: WhisperKitRuntimeMetric) {
        WhisperKitMetricLogger.log(metric)
        Task { @MainActor in
            WhisperKitDiagnosticsStore.shared.record(metric)
        }
    }
}

struct WhisperKitDiagnosticsSnapshot: Sendable, Equatable {
    var updatedAt: Date?
    var model: String?
    var modelRepo: String?
    var usesCustomModelFolder = false
    var sessionStartedAt: Date?
    var intervalMs: Int?
    var minimumSamples: Int?
    var requiredSegmentsForConfirmation: Int?
    var totalSamples: Int?
    var firstPartialLatencyMs: UInt64?
    var lastRealtimeDurationMs: UInt64?
    var lastRealtimeSampleCount: Int?
    var lastRealtimeSegmentCount: Int?
    var lastFinalDurationMs: UInt64?
    var lastFinalSegmentCount: Int?
    var lastDownloadDurationMs: UInt64?
    var lastLoadDurationMs: UInt64?
    var lastNativeTranscriptionDurationMs: UInt64?
    var lastNativeTranscriptionSampleCount: Int?
    var cacheHitCount = 0
    var partialEventCount = 0
    var committedEventCount = 0
    var errorEventCount = 0
    var lastError: String?
    var recentEvents: [WhisperKitDiagnosticsEvent] = []

    var hasData: Bool {
        updatedAt != nil
    }

    var modelText: String {
        guard let model else { return "No model yet" }
        return model
    }

    var modelSourceText: String {
        guard hasData else { return "No source yet" }
        return usesCustomModelFolder ? "Local folder" : "Model cache"
    }

    mutating func apply(_ metric: WhisperKitProviderMetric) {
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

    mutating func apply(_ metric: WhisperKitRuntimeMetric) {
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

struct WhisperKitDiagnosticsEvent: Sendable, Equatable, Identifiable {
    enum Level: Sendable, Equatable {
        case info
        case error
    }

    let id = UUID()
    var timestamp: Date
    var title: String
    var detail: String
    var level: Level

    static func == (lhs: WhisperKitDiagnosticsEvent, rhs: WhisperKitDiagnosticsEvent) -> Bool {
        lhs.id == rhs.id
            && lhs.timestamp == rhs.timestamp
            && lhs.title == rhs.title
            && lhs.detail == rhs.detail
            && lhs.level == rhs.level
    }
}
