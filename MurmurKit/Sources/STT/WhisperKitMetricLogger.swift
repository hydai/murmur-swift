import Foundation
import os

/// OSLog bridge for WhisperKit provider/runtime diagnostics.
public enum WhisperKitMetricLogger {
    private static let providerLogger = Logger(
        subsystem: "com.hydai.Murmur",
        category: "WhisperKitProvider"
    )
    private static let runtimeLogger = Logger(
        subsystem: "com.hydai.Murmur",
        category: "WhisperKitRuntime"
    )

    public static func log(_ metric: WhisperKitProviderMetric) {
        switch metric {
        case .sessionStarted(
            let model,
            let intervalMs,
            let minimumSamples,
            let requiredSegmentsForConfirmation
        ):
            providerLogger.info(
                """
                session_started model=\(model, privacy: .public) \
                interval_ms=\(intervalMs) minimum_samples=\(minimumSamples) \
                required_segments=\(requiredSegmentsForConfirmation)
                """
            )
        case .audioReceived(let totalSamples, let chunkSamples, let timestampMs):
            providerLogger.debug(
                """
                audio_received total_samples=\(totalSamples) \
                chunk_samples=\(chunkSamples) timestamp_ms=\(timestampMs)
                """
            )
        case .realtimePassStarted(let sampleCount, let confirmedEndSeconds):
            providerLogger.debug(
                """
                realtime_pass_started sample_count=\(sampleCount) \
                confirmed_end_s=\(Double(confirmedEndSeconds), format: .fixed(precision: 2))
                """
            )
        case .realtimePassFinished(let sampleCount, let segmentCount, let emittedEventCount, let durationMs):
            providerLogger.info(
                """
                realtime_pass_finished sample_count=\(sampleCount) \
                segments=\(segmentCount) emitted_events=\(emittedEventCount) \
                duration_ms=\(durationMs)
                """
            )
        case .realtimePassFailed(let sampleCount, let durationMs, let message):
            providerLogger.error(
                """
                realtime_pass_failed sample_count=\(sampleCount) \
                duration_ms=\(durationMs) error=\(message, privacy: .private)
                """
            )
        case .firstPartialLatency(let durationMs):
            providerLogger.info("first_partial_latency duration_ms=\(durationMs)")
        case .finalPassStarted(let sampleCount, let confirmedEndSeconds):
            providerLogger.info(
                """
                final_pass_started sample_count=\(sampleCount) \
                confirmed_end_s=\(Double(confirmedEndSeconds), format: .fixed(precision: 2))
                """
            )
        case .finalPassFinished(let segmentCount, let emittedEventCount, let durationMs):
            providerLogger.info(
                """
                final_pass_finished segments=\(segmentCount) \
                emitted_events=\(emittedEventCount) duration_ms=\(durationMs)
                """
            )
        case .finalPassFailed(let durationMs, let message):
            providerLogger.error(
                "final_pass_failed duration_ms=\(durationMs) error=\(message, privacy: .private)"
            )
        case .runtime(let metric):
            log(metric)
        case .sessionFinished(let totalSamples, let partialEvents, let committedEvents, let errorEvents):
            providerLogger.info(
                """
                session_finished total_samples=\(totalSamples) \
                partial_events=\(partialEvents) committed_events=\(committedEvents) \
                error_events=\(errorEvents)
                """
            )
        }
    }

    public static func log(_ metric: WhisperKitRuntimeMetric) {
        switch metric {
        case .cacheHit(let key):
            runtimeLogger.debug(
                """
                cache_hit model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) custom_folder=\(key.usesCustomModelFolder)
                """
            )
        case .awaitingInFlightLoad(let key):
            runtimeLogger.debug(
                """
                awaiting_in_flight_load model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) custom_folder=\(key.usesCustomModelFolder)
                """
            )
        case .downloadStarted(let key):
            runtimeLogger.info(
                """
                download_started model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public)
                """
            )
        case .downloadFinished(let key, let modelFolder, let durationMs):
            runtimeLogger.info(
                """
                download_finished model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) duration_ms=\(durationMs) \
                folder=\(modelFolder, privacy: .private)
                """
            )
        case .downloadFailed(let key, let durationMs, let message):
            runtimeLogger.error(
                """
                download_failed model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) duration_ms=\(durationMs) \
                error=\(message, privacy: .private)
                """
            )
        case .loadStarted(let key, let modelFolder, let prewarm):
            runtimeLogger.info(
                """
                load_started model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) prewarm=\(prewarm) \
                custom_folder=\(key.usesCustomModelFolder) folder=\(modelFolder, privacy: .private)
                """
            )
        case .loadFinished(let key, let durationMs):
            runtimeLogger.info(
                """
                load_finished model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) duration_ms=\(durationMs)
                """
            )
        case .loadFailed(let key, let durationMs, let message):
            runtimeLogger.error(
                """
                load_failed model=\(key.model, privacy: .public) \
                repo=\(key.modelRepo, privacy: .public) duration_ms=\(durationMs) \
                error=\(message, privacy: .private)
                """
            )
        case .transcriptionStarted(let key, let sampleCount, let clipStartSeconds):
            runtimeLogger.debug(
                """
                transcription_started model=\(key.model, privacy: .public) \
                sample_count=\(sampleCount) clip_start_s=\(clipStartSeconds.map(Double.init) ?? -1)
                """
            )
        case .transcriptionFinished(let key, let segmentCount, let durationMs):
            runtimeLogger.info(
                """
                transcription_finished model=\(key.model, privacy: .public) \
                segments=\(segmentCount) duration_ms=\(durationMs)
                """
            )
        case .transcriptionFailed(let key, let durationMs, let message):
            runtimeLogger.error(
                """
                transcription_failed model=\(key.model, privacy: .public) \
                duration_ms=\(durationMs) error=\(message, privacy: .private)
                """
            )
        }
    }
}

private extension WhisperKitRuntimeKey {
    var usesCustomModelFolder: Bool {
        !modelFolder.isEmpty
    }
}
