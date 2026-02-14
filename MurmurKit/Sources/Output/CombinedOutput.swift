import Foundation

/// Routes text output based on the configured OutputMode.
public struct CombinedOutput: OutputSink {
    private let mode: OutputMode
    private let clipboard: ClipboardOutput
    #if os(macOS)
    private let keyboard: KeyboardOutput
    #endif

    public init(mode: OutputMode) {
        self.mode = mode
        self.clipboard = ClipboardOutput()
        #if os(macOS)
        self.keyboard = KeyboardOutput()
        #endif
    }

    public func outputText(_ text: String) async throws {
        switch mode {
        case .clipboard:
            try await clipboard.outputText(text)

        case .keyboard:
            #if os(macOS)
            try await keyboard.outputText(text)
            #else
            try await clipboard.outputText(text)
            #endif

        case .both:
            try await clipboard.outputText(text)
            #if os(macOS)
            try await keyboard.outputText(text)
            #endif
        }
    }
}
