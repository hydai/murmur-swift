import Foundation

/// Protocol for text output destinations.
public protocol OutputSink: Sendable {
    /// Output the processed text to the destination.
    func outputText(_ text: String) async throws
}
