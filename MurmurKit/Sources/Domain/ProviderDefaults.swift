import Foundation

/// Single source of truth for provider model defaults and API-key dictionary
/// keys. Replaces hardcoded strings previously scattered across
/// `PipelineViewModel.createLlmProcessor`, `SettingsViewModel.createLlmProcessor`,
/// and each provider's own `init` default.
///
/// Mirrors the Rust `create_llm_processor` factory in `lt-tauri/src/main.rs`.
public enum ProviderDefaults {
    // MARK: - LLM default models

    /// Default model name for a given LLM processor. Empty for processors
    /// that don't expose a model concept (Apple Foundation Models).
    public static func defaultModel(for processor: LlmProcessorType) -> String {
        switch processor {
        case .appleLlm:     return ""
        case .gemini:       return "gemini-3-flash-preview"
        case .copilot:      return "gpt-5-mini"
        case .openAILlm:    return "gpt-4o-mini"
        case .claude:       return "claude-sonnet-4-20250514"
        case .geminiApi:    return "gemini-2.0-flash"
        case .customOpenAI: return "gpt-4o-mini"
        }
    }

    // MARK: - STT default models

    public static let elevenLabsModel  = "scribe_v2_realtime"
    public static let openAISttModel   = "whisper-1"
    public static let groqSttModel     = "whisper-large-v3-turbo"
    public static let customSttModel   = "whisper-1"

    // MARK: - API-key dictionary names

    /// Stable identifiers used as keys in `AppConfig.apiKeys`. Defining them
    /// here prevents typos like `"elven_labs"` from silently breaking auth.
    public enum ApiKey {
        public static let elevenLabs   = "elevenlabs"
        public static let openAI       = "openai"
        public static let groq         = "groq"
        public static let anthropic    = "anthropic"
        public static let googleAI     = "google_ai"
        public static let customOpenAI = "custom_openai"
        public static let customStt    = "custom_stt"
        /// Optional override for the OpenAI LLM endpoint; falls back to
        /// `openai` when missing.
        public static let openAILlm    = "openai_llm"
    }
}
