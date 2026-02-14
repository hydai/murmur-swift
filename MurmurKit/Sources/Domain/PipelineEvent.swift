import Foundation

/// Events emitted by the pipeline orchestrator for UI consumption.
public enum PipelineEvent: Sendable {
    /// Pipeline state changed.
    case stateChanged(PipelineState)

    /// Real-time audio level update.
    case audioLevel(AudioLevel)

    /// Interim transcription text.
    case partialTranscription(String)

    /// Final transcription segment.
    case committedTranscription(String)

    /// Voice command was detected.
    case commandDetected(String)

    /// Final processed result.
    case finalResult(text: String, processingTimeMs: UInt64)

    /// An error occurred.
    case error(message: String, recoverable: Bool)
}
