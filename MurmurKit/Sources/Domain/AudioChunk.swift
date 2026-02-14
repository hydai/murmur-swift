import Foundation

/// A chunk of PCM audio data: 16kHz mono Int16 samples.
public struct AudioChunk: Sendable {
    /// 16-bit signed PCM samples at 16kHz mono.
    public let data: [Int16]

    /// Milliseconds from session start.
    public let timestampMs: UInt64

    public init(data: [Int16], timestampMs: UInt64) {
        self.data = data
        self.timestampMs = timestampMs
    }

    /// Duration of this chunk in milliseconds.
    public var durationMs: UInt64 {
        guard !data.isEmpty else { return 0 }
        return UInt64(data.count) * 1000 / 16000
    }
}

/// Real-time audio level information for UI visualization.
public struct AudioLevel: Sendable {
    /// RMS level normalized to 0.0–1.0.
    public let rms: Float

    /// Whether voice activity is detected.
    public let voiceActive: Bool

    /// Milliseconds from session start.
    public let timestampMs: UInt64

    public init(rms: Float, voiceActive: Bool, timestampMs: UInt64) {
        self.rms = rms
        self.voiceActive = voiceActive
        self.timestampMs = timestampMs
    }
}
