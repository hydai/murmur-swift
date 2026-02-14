import Foundation

/// Protocol for LLM text processors.
public protocol LlmProcessor: Sendable {
    /// Process a task and return the result.
    func process(_ task: ProcessingTask) async throws -> ProcessingOutput

    /// Check if the processor is available and working.
    func healthCheck() async -> Bool
}
