import Foundation

/// An in-memory map of prompt overrides. A missing entry falls back to the
/// compile-time default in `PromptName.defaultTemplate`.
///
/// Mirrors the Rust `PromptSet` type. Sendable so it can cross actor
/// boundaries between the UI, the prompt store, and LLM processors.
public struct PromptSet: Sendable, Equatable {
    private var overrides: [PromptName: String]

    public init(overrides: [PromptName: String] = [:]) {
        self.overrides = overrides
    }

    /// Resolved template for `name` — override if present, default otherwise.
    public func get(_ name: PromptName) -> String {
        overrides[name] ?? name.defaultTemplate
    }

    public func hasOverride(_ name: PromptName) -> Bool {
        overrides[name] != nil
    }

    public mutating func setOverride(_ name: PromptName, content: String) {
        overrides[name] = content
    }

    public mutating func clearOverride(_ name: PromptName) {
        overrides.removeValue(forKey: name)
    }

    public var overriddenNames: Set<PromptName> {
        Set(overrides.keys)
    }
}
