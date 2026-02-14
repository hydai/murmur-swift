import Foundation

/// RMS-based voice activity detection.
public struct VadProcessor: Sendable {
    /// RMS threshold for voice activity (0.0–1.0, typical: 0.01–0.05).
    public let threshold: Float

    public init(threshold: Float = 0.02) {
        self.threshold = threshold
    }

    /// Calculate RMS and detect voice activity.
    public func process(samples: [Int16], timestampMs: UInt64) -> AudioLevel {
        let rms = Self.calculateRMS(samples)
        return AudioLevel(
            rms: rms,
            voiceActive: rms > threshold,
            timestampMs: timestampMs
        )
    }

    /// Calculate RMS level normalized to 0.0–1.0 from 16-bit samples.
    public static func calculateRMS(_ samples: [Int16]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let maxValue = Float(Int16.max)
        var sumOfSquares: Float = 0
        for sample in samples {
            let normalized = Float(sample) / maxValue
            sumOfSquares += normalized * normalized
        }
        return sqrt(sumOfSquares / Float(samples.count))
    }
}
