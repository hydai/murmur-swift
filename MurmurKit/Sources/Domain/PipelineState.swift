import Foundation

/// States of the voice processing pipeline.
public enum PipelineState: String, Sendable {
    case idle
    case recording
    case transcribing
    case processing
    case done
    case error
}
