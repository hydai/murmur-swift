import Foundation
import Testing
@testable import MurmurKit

@Suite("TranscriptionAccumulator")
struct TranscriptionAccumulatorTests {
    @Test("Single committed segment finalises to itself")
    func singleCommitted() {
        var acc = TranscriptionAccumulator()
        acc.handle(.committed(text: "hello world", timestampMs: 0))
        #expect(acc.finalize() == "hello world")
    }

    @Test("Multiple committed segments are joined by a single space")
    func multipleCommitted() {
        var acc = TranscriptionAccumulator()
        acc.handle(.committed(text: "first sentence.", timestampMs: 0))
        acc.handle(.committed(text: "second sentence.", timestampMs: 0))
        #expect(acc.finalize() == "first sentence. second sentence.")
    }

    @Test("Trailing partial is appended when no committed event follows")
    func trailingPartialIsAppended() {
        var acc = TranscriptionAccumulator()
        acc.handle(.committed(text: "committed prefix", timestampMs: 0))
        acc.handle(.partial(text: "trailing partial", timestampMs: 0))
        #expect(acc.finalize() == "committed prefix trailing partial")
    }

    @Test("Partial-only stream uses last partial as final transcript")
    func partialOnlyStream() {
        // Mirrors Apple SpeechTranscriber, which only emits partials.
        var acc = TranscriptionAccumulator()
        acc.handle(.partial(text: "first guess", timestampMs: 0))
        acc.handle(.partial(text: "better guess", timestampMs: 0))
        acc.handle(.partial(text: "final guess", timestampMs: 0))
        #expect(acc.finalize() == "final guess")
    }

    @Test("Partial is dropped when a later committed event arrives")
    func partialIsResetOnCommit() {
        var acc = TranscriptionAccumulator()
        acc.handle(.partial(text: "interim", timestampMs: 0))
        acc.handle(.committed(text: "committed", timestampMs: 0))
        #expect(acc.finalize() == "committed")
    }

    @Test("Empty stream finalises to empty string")
    func emptyStream() {
        var acc = TranscriptionAccumulator()
        #expect(acc.finalize() == "")
    }

    @Test("Errors do not corrupt accumulator state")
    func errorsAreIgnored() {
        var acc = TranscriptionAccumulator()
        acc.handle(.committed(text: "real", timestampMs: 0))
        acc.handle(.error(message: "boom"))
        acc.handle(.committed(text: "again", timestampMs: 0))
        #expect(acc.finalize() == "real again")
    }

    @Test("Finalize trims surrounding whitespace")
    func finalizeTrimsWhitespace() {
        var acc = TranscriptionAccumulator()
        acc.handle(.committed(text: "  padded ", timestampMs: 0))
        #expect(acc.finalize() == "padded")
    }
}
