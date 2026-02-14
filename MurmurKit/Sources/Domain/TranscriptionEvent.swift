import Foundation

/// Events emitted by an STT provider during transcription.
public enum TranscriptionEvent: Sendable {
    /// Interim/partial transcription result (may change).
    case partial(text: String, timestampMs: UInt64)

    /// Final/committed transcription segment (will not change).
    case committed(text: String, timestampMs: UInt64)

    /// Transcription error.
    case error(message: String)
}
