import Foundation

/// Placeholder for providers that exist in config but are unavailable on the
/// current platform, such as CLI-backed processors on iOS.
public actor UnsupportedLlmProcessor: LlmProcessor {
    private let displayName: String

    public init(displayName: String) {
        self.displayName = displayName
    }

    public func process(_ task: ProcessingTask) async throws -> ProcessingOutput {
        throw MurmurError.llm("\(displayName) is not available on this platform")
    }

    public func healthCheck() async -> Bool {
        false
    }
}
