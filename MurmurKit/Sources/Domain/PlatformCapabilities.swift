import Foundation

/// Runtime-independent platform capability flags used by shared UI and
/// factories to avoid assuming the macOS feature set exists everywhere.
public enum PlatformCapabilities {
    public static var supportsGlobalHotkey: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    public static var supportsKeyboardInjection: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    public static var supportsClipboardOutput: Bool {
        #if canImport(AppKit) || canImport(UIKit)
        true
        #else
        false
        #endif
    }

    public static var supportsCLIProcessors: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    public static var supportsSparkleUpdates: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    public static var supportsModelDownloads: Bool {
        true
    }

    public static var availableLlmProcessors: [LlmProcessorType] {
        var processors: [LlmProcessorType] = [
            .appleLlm,
            .openAILlm,
            .claude,
            .geminiApi,
            .customOpenAI,
        ]

        if supportsCLIProcessors {
            processors.insert(.gemini, at: 1)
            processors.insert(.copilot, at: 2)
        }

        return processors
    }

    public static var availableOutputModes: [OutputMode] {
        OutputMode.availableModes()
    }
}
