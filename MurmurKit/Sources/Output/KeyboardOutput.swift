#if os(macOS)
import CoreGraphics
import Foundation

/// Simulates keyboard input using CGEvent. macOS only.
///
/// Requires Accessibility permissions to inject keystrokes into other apps.
public struct KeyboardOutput: OutputSink {
    public init() {}

    public func outputText(_ text: String) async throws {
        let source = CGEventSource(stateID: .hidSystemState)

        for char in text.unicodeScalars {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            var utf16 = [UniChar](String(char).utf16)
            keyDown?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            keyUp?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            // Small delay between keystrokes for reliable input
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}
#endif
