import Foundation

/// STT provider selection.
public enum SttProviderType: String, Codable, Sendable, CaseIterable, Hashable {
    case appleStt
    case whisperKit
    case elevenLabs
    case openAI
    case groq
    case customStt
}

/// LLM processor selection.
public enum LlmProcessorType: String, Codable, Sendable, CaseIterable, Hashable {
    case appleLlm
    case gemini
    case copilot
    case openAILlm
    case claude
    case geminiApi
    case customOpenAI
}

/// Configuration for custom OpenAI-compatible STT endpoints.
public struct HttpSttConfig: Codable, Sendable {
    public var customBaseUrl: String
    public var customDisplayName: String
    public var customModel: String

    public init(customBaseUrl: String = "http://localhost:8080", customDisplayName: String = "Custom STT", customModel: String = "whisper-1") {
        self.customBaseUrl = customBaseUrl
        self.customDisplayName = customDisplayName
        self.customModel = customModel
    }
}

/// Configuration for native Argmax WhisperKit STT.
public struct WhisperKitSttConfig: Codable, Sendable, Equatable {
    public var model: String
    public var modelRepo: String
    public var modelFolder: String
    public var prewarm: Bool
    public var realtimeIntervalMilliseconds: Int
    public var realtimeMinimumSamples: Int
    public var realtimeRequiredSegmentsForConfirmation: Int

    private enum CodingKeys: String, CodingKey {
        case model
        case modelRepo
        case modelFolder
        case prewarm
        case realtimeIntervalMilliseconds
        case realtimeMinimumSamples
        case realtimeRequiredSegmentsForConfirmation
    }

    public init(
        model: String = ProviderDefaults.whisperKitSttModel,
        modelRepo: String = ProviderDefaults.whisperKitModelRepo,
        modelFolder: String = "",
        prewarm: Bool = false,
        realtimeIntervalMilliseconds: Int = WhisperKitRealtimeOptions().intervalMilliseconds,
        realtimeMinimumSamples: Int = WhisperKitRealtimeOptions().minimumSamples,
        realtimeRequiredSegmentsForConfirmation: Int = WhisperKitRealtimeOptions().requiredSegmentsForConfirmation
    ) {
        let realtimeOptions = WhisperKitRealtimeOptions(
            intervalMilliseconds: realtimeIntervalMilliseconds,
            minimumSamples: realtimeMinimumSamples,
            requiredSegmentsForConfirmation: realtimeRequiredSegmentsForConfirmation
        )
        self.model = model
        self.modelRepo = modelRepo
        self.modelFolder = modelFolder
        self.prewarm = prewarm
        self.realtimeIntervalMilliseconds = realtimeOptions.intervalMilliseconds
        self.realtimeMinimumSamples = realtimeOptions.minimumSamples
        self.realtimeRequiredSegmentsForConfirmation = realtimeOptions.requiredSegmentsForConfirmation
    }

    public var realtimeOptions: WhisperKitRealtimeOptions {
        WhisperKitRealtimeOptions(
            intervalMilliseconds: realtimeIntervalMilliseconds,
            minimumSamples: realtimeMinimumSamples,
            requiredSegmentsForConfirmation: realtimeRequiredSegmentsForConfirmation
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            model: try container.decodeIfPresent(String.self, forKey: .model)
                ?? ProviderDefaults.whisperKitSttModel,
            modelRepo: try container.decodeIfPresent(String.self, forKey: .modelRepo)
                ?? ProviderDefaults.whisperKitModelRepo,
            modelFolder: try container.decodeIfPresent(String.self, forKey: .modelFolder)
                ?? "",
            prewarm: try container.decodeIfPresent(Bool.self, forKey: .prewarm)
                ?? false,
            realtimeIntervalMilliseconds: try container.decodeIfPresent(
                Int.self,
                forKey: .realtimeIntervalMilliseconds
            ) ?? WhisperKitRealtimeOptions().intervalMilliseconds,
            realtimeMinimumSamples: try container.decodeIfPresent(
                Int.self,
                forKey: .realtimeMinimumSamples
            ) ?? WhisperKitRealtimeOptions().minimumSamples,
            realtimeRequiredSegmentsForConfirmation: try container.decodeIfPresent(
                Int.self,
                forKey: .realtimeRequiredSegmentsForConfirmation
            ) ?? WhisperKitRealtimeOptions().requiredSegmentsForConfirmation
        )
    }
}

/// Configuration for custom OpenAI-compatible LLM endpoints.
public struct HttpLlmConfig: Codable, Sendable {
    public var customBaseUrl: String
    public var customDisplayName: String

    public init(customBaseUrl: String = "http://localhost:11434/v1", customDisplayName: String = "Ollama") {
        self.customBaseUrl = customBaseUrl
        self.customDisplayName = customDisplayName
    }
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
    /// Optional model override — empty string means use provider default.
    public var llmModel: String
    /// Configuration for custom OpenAI-compatible LLM endpoints.
    public var httpLlmConfig: HttpLlmConfig
    /// Configuration for custom OpenAI-compatible STT endpoints.
    public var httpSttConfig: HttpSttConfig
    /// Configuration for native WhisperKit STT.
    public var whisperKitSttConfig: WhisperKitSttConfig

    public init(
        sttProvider: SttProviderType = .appleStt,
        apiKeys: [String: String] = [:],
        hotkey: String = "Ctrl+`",
        llmProcessor: LlmProcessorType = .appleLlm,
        outputMode: OutputMode = .clipboard,
        uiPreferences: UiPreferences = UiPreferences(),
        appleSttLocale: String = "auto",
        personalDictionary: PersonalDictionary = PersonalDictionary(),
        sttLanguage: String = "auto",
        llmModel: String = "",
        httpLlmConfig: HttpLlmConfig = HttpLlmConfig(),
        httpSttConfig: HttpSttConfig = HttpSttConfig(),
        whisperKitSttConfig: WhisperKitSttConfig = WhisperKitSttConfig()
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
        self.llmModel = llmModel
        self.httpLlmConfig = httpLlmConfig
        self.httpSttConfig = httpSttConfig
        self.whisperKitSttConfig = whisperKitSttConfig
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
        llmModel = try container.decodeIfPresent(String.self, forKey: .llmModel) ?? ""
        httpLlmConfig = try container.decodeIfPresent(HttpLlmConfig.self, forKey: .httpLlmConfig) ?? HttpLlmConfig()
        httpSttConfig = try container.decodeIfPresent(HttpSttConfig.self, forKey: .httpSttConfig) ?? HttpSttConfig()
        whisperKitSttConfig = try container.decodeIfPresent(WhisperKitSttConfig.self, forKey: .whisperKitSttConfig) ?? WhisperKitSttConfig()
    }

    /// Returns a copy with options that cannot run on the current platform
    /// mapped to the closest supported behavior.
    public func normalizedForCurrentPlatform() -> AppConfig {
        var copy = self
        if !PlatformCapabilities.availableLlmProcessors.contains(copy.llmProcessor) {
            copy.llmProcessor = .appleLlm
        }
        copy.outputMode = copy.outputMode.normalized()
        return copy
    }
}
