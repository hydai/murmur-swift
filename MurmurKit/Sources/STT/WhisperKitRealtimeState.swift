import Foundation

/// Lightweight segment representation used to keep WhisperKit types out of
/// the rest of MurmurKit's STT pipeline.
public struct WhisperKitTranscriptSegment: Sendable, Equatable {
    public var text: String
    public var start: Float
    public var end: Float

    public init(text: String, start: Float, end: Float) {
        self.text = text
        self.start = start
        self.end = end
    }
}

struct WhisperKitRealtimeState: Sendable, Equatable {
    var confirmedEndSeconds: Float = 0

    private var previousHypothesis: [WhisperKitTranscriptSegment] = []
    private var lastPartialText: String = ""
    private let requiredSegmentsForConfirmation: Int

    init(requiredSegmentsForConfirmation: Int = 2) {
        self.requiredSegmentsForConfirmation = max(0, requiredSegmentsForConfirmation)
    }

    mutating func handleHypothesis(_ segments: [WhisperKitTranscriptSegment]) -> [TranscriptionEvent] {
        let candidates = unconfirmedSegments(from: segments)
        var events: [TranscriptionEvent] = []
        var remaining = candidates

        let commonPrefix = Self.commonPrefix(previousHypothesis, candidates)
        if commonPrefix.count > requiredSegmentsForConfirmation {
            let committed = Array(commonPrefix.dropLast(requiredSegmentsForConfirmation))
            if let last = committed.last {
                confirmedEndSeconds = max(confirmedEndSeconds, last.end)
                let text = Self.joinText(committed)
                if !text.isEmpty {
                    events.append(.committed(
                        text: text,
                        timestampMs: Self.timestampMs(committed.first?.start ?? last.start)
                    ))
                }
                remaining = unconfirmedSegments(from: candidates)
            }
        }

        let partial = Self.joinText(remaining)
        if partial != lastPartialText {
            events.append(.partial(
                text: partial,
                timestampMs: Self.timestampMs(remaining.first?.start ?? confirmedEndSeconds)
            ))
            lastPartialText = partial
        }

        previousHypothesis = remaining
        return events
    }

    mutating func finalize(_ segments: [WhisperKitTranscriptSegment]) -> [TranscriptionEvent] {
        let remaining = unconfirmedSegments(from: segments)
        previousHypothesis = []
        lastPartialText = ""

        guard !remaining.isEmpty else { return [] }
        if let last = remaining.last {
            confirmedEndSeconds = max(confirmedEndSeconds, last.end)
        }

        let text = Self.joinText(remaining)
        guard !text.isEmpty else { return [] }
        return [.committed(
            text: text,
            timestampMs: Self.timestampMs(remaining.first?.start ?? confirmedEndSeconds)
        )]
    }

    private func unconfirmedSegments(
        from segments: [WhisperKitTranscriptSegment]
    ) -> [WhisperKitTranscriptSegment] {
        segments.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.end > confirmedEndSeconds + 0.01
        }
    }

    private static func commonPrefix(
        _ lhs: [WhisperKitTranscriptSegment],
        _ rhs: [WhisperKitTranscriptSegment]
    ) -> [WhisperKitTranscriptSegment] {
        zip(lhs, rhs)
            .prefix { normalized($0.0.text) == normalized($0.1.text) }
            .map { $0.1 }
    }

    private static func joinText(_ segments: [WhisperKitTranscriptSegment]) -> String {
        segments
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func timestampMs(_ seconds: Float) -> UInt64 {
        UInt64(max(0, seconds) * 1000)
    }
}
