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
