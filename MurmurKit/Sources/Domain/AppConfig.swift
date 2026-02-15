import Foundation

/// STT provider selection.
public enum SttProviderType: String, Codable, Sendable, CaseIterable {
    case appleStt
    case elevenLabs
    case openAI
    case groq
}

/// LLM processor selection.
public enum LlmProcessorType: String, Codable, Sendable, CaseIterable {
    case appleLlm
    case gemini
    case copilot
}

/// UI display preferences.
public struct UiPreferences: Codable, Sendable {
    public var opacity: Float
    public var showWaveform: Bool
    public var theme: String

    public init(opacity: Float = 0.9, showWaveform: Bool = true, theme: String = "dark") {
        self.opacity = opacity
        self.showWaveform = showWaveform
        self.theme = theme
    }
}

/// Application configuration, persisted as JSON.
public struct AppConfig: Codable, Sendable {
    public var sttProvider: SttProviderType
    public var apiKeys: [String: String]
    public var hotkey: String
    public var llmProcessor: LlmProcessorType
    public var outputMode: OutputMode
    public var uiPreferences: UiPreferences
    public var appleSttLocale: String
    public var personalDictionary: PersonalDictionary
    /// Language hint for cloud STT providers (ISO 639-1, e.g. "zh", "en", "ja").
    /// "auto" means no hint — let the API auto-detect.
    public var sttLanguage: String

    public init(
        sttProvider: SttProviderType = .appleStt,
        apiKeys: [String: String] = [:],
        hotkey: String = "Ctrl+`",
        llmProcessor: LlmProcessorType = .appleLlm,
        outputMode: OutputMode = .clipboard,
        uiPreferences: UiPreferences = UiPreferences(),
        appleSttLocale: String = "auto",
        personalDictionary: PersonalDictionary = PersonalDictionary(),
        sttLanguage: String = "auto"
    ) {
        self.sttProvider = sttProvider
        self.apiKeys = apiKeys
        self.hotkey = hotkey
        self.llmProcessor = llmProcessor
        self.outputMode = outputMode
        self.uiPreferences = uiPreferences
        self.appleSttLocale = appleSttLocale
        self.personalDictionary = personalDictionary
        self.sttLanguage = sttLanguage
    }

    // Custom decoder for backward compatibility — existing config files
    // without `stt_language` will load cleanly with the default value.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sttProvider = try container.decode(SttProviderType.self, forKey: .sttProvider)
        apiKeys = try container.decode([String: String].self, forKey: .apiKeys)
        hotkey = try container.decode(String.self, forKey: .hotkey)
        llmProcessor = try container.decode(LlmProcessorType.self, forKey: .llmProcessor)
        outputMode = try container.decode(OutputMode.self, forKey: .outputMode)
        uiPreferences = try container.decode(UiPreferences.self, forKey: .uiPreferences)
        appleSttLocale = try container.decode(String.self, forKey: .appleSttLocale)
        personalDictionary = try container.decode(PersonalDictionary.self, forKey: .personalDictionary)
        sttLanguage = try container.decodeIfPresent(String.self, forKey: .sttLanguage) ?? "auto"
    }
}
