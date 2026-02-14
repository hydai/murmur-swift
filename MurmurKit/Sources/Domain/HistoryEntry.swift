import Foundation

/// A single transcription history entry.
public struct HistoryEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let rawText: String
    public let processedText: String
    public let command: String?
    public let timestamp: Date
    public let processingTimeMs: UInt64

    public init(
        id: UUID = UUID(),
        rawText: String,
        processedText: String,
        command: String? = nil,
        timestamp: Date = Date(),
        processingTimeMs: UInt64 = 0
    ) {
        self.id = id
        self.rawText = rawText
        self.processedText = processedText
        self.command = command
        self.timestamp = timestamp
        self.processingTimeMs = processingTimeMs
    }
}
