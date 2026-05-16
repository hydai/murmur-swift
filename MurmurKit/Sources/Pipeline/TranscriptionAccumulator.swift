import Foundation

/// Stateful accumulator that combines streamed `TranscriptionEvent`s into a
/// single committed transcript, with a trailing-partial fallback used by
/// providers like Apple SpeechTranscriber that only emit partials.
///
/// Mirrors the Rust `lt-pipeline/src/orchestrator.rs:187-200` behavior:
/// when the event stream ends, any uncommitted `lastPartialText` is appended
/// so it isn't lost.
public struct TranscriptionAccumulator: Sendable, Equatable {
    public private(set) var fullTranscription: String = ""
    public private(set) var lastPartialText: String = ""

    public init() {}

    /// Apply an event from the STT stream. Errors are ignored at this layer —
    /// callers handle them separately.
    public mutating func handle(_ event: TranscriptionEvent) {
        switch event {
        case .partial(let text, _):
            lastPartialText = text
        case .committed(let text, _):
            if !fullTranscription.isEmpty { fullTranscription += " " }
            fullTranscription += text
            lastPartialText = ""
        case .error:
            break
        }
    }

    /// Called when the event stream ends. Appends any uncommitted trailing
    /// partial text to the full transcription and returns the trimmed result.
    public mutating func finalize() -> String {
        if !lastPartialText.isEmpty {
            if !fullTranscription.isEmpty { fullTranscription += " " }
            fullTranscription += lastPartialText
            lastPartialText = ""
        }
        return fullTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
