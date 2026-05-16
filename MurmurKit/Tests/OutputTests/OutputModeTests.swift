#if canImport(AppKit)
import AppKit
import Foundation
import Testing
@testable import MurmurKit

@Suite("CombinedOutput routing", .serialized)
struct OutputModeTests {
    /// Pre-write a known sentinel to the pasteboard, run the sink, and report
    /// whether the pasteboard now holds our output (clipboard touched) or the
    /// sentinel (clipboard untouched).
    private func clipboardWasWritten(by sink: CombinedOutput, text: String) async throws -> Bool {
        let sentinel = "MURMUR_TEST_SENTINEL_\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)

        try await sink.outputText(text)

        let after = NSPasteboard.general.string(forType: .string) ?? ""
        return after == text
    }

    @Test(".clipboard mode writes to NSPasteboard")
    func clipboardMode() async throws {
        let sink = CombinedOutput(mode: .clipboard)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(written)
    }

    @Test(".keyboard mode does not touch NSPasteboard")
    func keyboardMode() async throws {
        // KeyboardOutput may silently no-op without Accessibility, but the
        // important guarantee is that .keyboard never falls back to clipboard.
        let sink = CombinedOutput(mode: .keyboard)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(!written)
    }

    @Test(".both mode writes to NSPasteboard")
    func bothMode() async throws {
        let sink = CombinedOutput(mode: .both)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(written)
    }
}
#endif
