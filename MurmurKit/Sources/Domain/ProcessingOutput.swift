import Foundation

/// Result from LLM processing.
public struct ProcessingOutput: Sendable {
    /// The processed text.
    public let text: String

    /// How long processing took in milliseconds.
    public let processingTimeMs: UInt64

    public init(text: String, processingTimeMs: UInt64) {
        self.text = text
        self.processingTimeMs = processingTimeMs
    }
}
