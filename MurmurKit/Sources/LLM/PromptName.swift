import Foundation

/// One of the five LLM prompt templates the pipeline can run.
public enum PromptName: String, CaseIterable, Sendable, Hashable {
    case postProcess   = "post_process"
    case shorten       = "shorten"
    case changeTone    = "change_tone"
    case generateReply = "generate_reply"
    case translate     = "translate"

    /// Filename-friendly snake_case identifier (matches Rust `PromptName::as_str`).
    public var fileStem: String { rawValue }

    /// Compile-time default markdown template. User overrides at
    /// `{configDir}/prompts/{fileStem}.md` win when present.
    public var defaultTemplate: String {
        switch self {
        case .postProcess:   return DefaultPromptTemplates.postProcess
        case .shorten:       return DefaultPromptTemplates.shorten
        case .changeTone:    return DefaultPromptTemplates.changeTone
        case .generateReply: return DefaultPromptTemplates.generateReply
        case .translate:     return DefaultPromptTemplates.translate
        }
    }

    /// Required placeholder tokens (e.g. `{dictionary_terms}`) that overrides
    /// MUST preserve for the substitution code to work. Used by the Settings
    /// UI to warn the user when an edit removes a required token.
    public var requiredPlaceholders: [String] {
        switch self {
        case .postProcess:   return ["{dictionary_terms}"]
        case .shorten:       return []
        case .changeTone:    return ["{tone}"]
        case .generateReply: return []
        case .translate:     return ["{language}"]
        }
    }
}
