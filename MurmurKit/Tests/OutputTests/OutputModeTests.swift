#if canImport(AppKit)
import AppKit
#endif
import Foundation
import Testing
@testable import MurmurKit

@Suite("CombinedOutput routing", .serialized)
struct OutputModeTests {
    /// Pre-write a known sentinel to the pasteboard, run the sink, and report
    /// whether the pasteboard now holds our output (clipboard touched) or the
    /// sentinel (clipboard untouched).
    #if canImport(AppKit)
    private func clipboardWasWritten(by sink: CombinedOutput, text: String) async throws -> Bool {
        let sentinel = "MURMUR_TEST_SENTINEL_\(UUID().uuidString)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sentinel, forType: .string)

        try await sink.outputText(text)

        let after = NSPasteboard.general.string(forType: .string) ?? ""
        return after == text
    }
    #endif

    @Test(".clipboard mode writes to NSPasteboard")
    func clipboardMode() async throws {
        #if canImport(AppKit)
        let sink = CombinedOutput(mode: .clipboard)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(written)
        #endif
    }

    @Test(".keyboard mode does not touch NSPasteboard")
    func keyboardMode() async throws {
        #if canImport(AppKit)
        // KeyboardOutput may silently no-op without Accessibility, but the
        // important guarantee is that .keyboard never falls back to clipboard.
        let sink = CombinedOutput(mode: .keyboard)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(!written)
        #endif
    }

    @Test(".both mode writes to NSPasteboard")
    func bothMode() async throws {
        #if canImport(AppKit)
        let sink = CombinedOutput(mode: .both)
        let written = try await clipboardWasWritten(by: sink, text: "hello")
        #expect(written)
        #endif
    }

    @Test("Mobile platforms expose clipboard as the only automatic output mode")
    func mobileAvailableModes() {
        #expect(OutputMode.availableModes(supportsKeyboardInjection: false) == [.clipboard])
    }

    @Test("Unsupported keyboard output normalizes to clipboard on mobile")
    func mobileOutputFallback() {
        #expect(OutputMode.clipboard.normalized(supportsKeyboardInjection: false) == .clipboard)
        #expect(OutputMode.keyboard.normalized(supportsKeyboardInjection: false) == .clipboard)
        #expect(OutputMode.both.normalized(supportsKeyboardInjection: false) == .clipboard)
    }

    @Test("Desktop platforms preserve automatic output modes")
    func desktopOutputModes() {
        #expect(OutputMode.availableModes(supportsKeyboardInjection: true) == OutputMode.allCases)
        #expect(OutputMode.keyboard.normalized(supportsKeyboardInjection: true) == .keyboard)
        #expect(OutputMode.both.normalized(supportsKeyboardInjection: true) == .both)
    }
}
