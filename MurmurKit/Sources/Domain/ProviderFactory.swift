import Foundation

/// Factory for creating STT providers and LLM processors based on AppConfig.
/// This decouples the instantiation logic from the ViewModel or UI layer.
public struct ProviderFactory: Sendable {
    private let configDir: URL
    private let whisperKitMetricHandler: @Sendable (WhisperKitProviderMetric) -> Void

    public init(
        configDir: URL = ConfigManager.defaultDirectory,
        whisperKitMetricHandler: @escaping @Sendable (WhisperKitProviderMetric) -> Void = {
            WhisperKitMetricLogger.log($0)
        }
    ) {
        self.configDir = configDir
        self.whisperKitMetricHandler = whisperKitMetricHandler
    }

    /// Creates an STT provider from the current configuration.
    public func createSttProvider(from config: AppConfig) -> any SttProvider {
        // Convert "auto" to nil — nil means let the API auto-detect
        let lang: String? = config.sttLanguage == "auto" ? nil : config.sttLanguage

        switch config.sttProvider {
        case .appleStt:
            let locale = config.appleSttLocale == "auto" ? nil : Locale(identifier: config.appleSttLocale)
            return AppleSttProvider(locale: locale)
        case .whisperKit:
            return WhisperKitProvider(
                config: config.whisperKitSttConfig,
                language: lang,
                realtimeOptions: config.whisperKitSttConfig.realtimeOptions,
                onMetric: whisperKitMetricHandler
            )
        case .elevenLabs:
            let key = config.apiKeys[ProviderDefaults.ApiKey.elevenLabs] ?? ""
            let elevenLabsLang: String? = lang.flatMap { ElevenLabsLanguages.iso639_3(for: $0) ?? $0 }
            return ElevenLabsProvider(apiKey: key, languageCode: elevenLabsLang)
        case .openAI:
            let key = config.apiKeys[ProviderDefaults.ApiKey.openAI] ?? ""
            return OpenAIProvider(apiKey: key, language: lang)
        case .groq:
            let key = config.apiKeys[ProviderDefaults.ApiKey.groq] ?? ""
            return GroqProvider(apiKey: key, language: lang)
        case .customStt:
            let raw = config.apiKeys[ProviderDefaults.ApiKey.customStt] ?? ""
            return CustomSttProvider(
                apiKey: raw.isEmpty ? nil : raw,
                model: config.httpSttConfig.customModel,
                baseURL: config.httpSttConfig.customBaseUrl,
                language: lang
            )
        }
    }

    /// Creates an LLM processor from the current configuration.
    public func createLlmProcessor(from config: AppConfig) async -> any LlmProcessor {
        let modelOverride = config.llmModel.isEmpty ? nil : config.llmModel
        func resolved(_ type: LlmProcessorType) -> String {
            modelOverride ?? ProviderDefaults.defaultModel(for: type)
        }

        // Load prompt overrides on a background thread to avoid blocking
        // the caller's executor (e.g. @MainActor) with synchronous disk I/O.
        let dir = self.configDir
        let promptSet = await Task.detached {
            (try? PromptStore.loadAll(configDir: dir)) ?? PromptSet()
        }.value
        let promptManager = PromptManager(set: promptSet)

        switch config.llmProcessor {
        case .appleLlm:
            return AppleLlmProcessor(promptManager: promptManager)
        case .gemini:
            #if os(macOS)
            return GeminiProcessor(model: resolved(.gemini), promptManager: promptManager)
            #else
            return UnsupportedLlmProcessor(displayName: "Gemini CLI")
            #endif
        case .copilot:
            #if os(macOS)
            return CopilotProcessor(model: resolved(.copilot), promptManager: promptManager)
            #else
            return UnsupportedLlmProcessor(displayName: "Copilot CLI")
            #endif
        case .openAILlm:
            let key = config.apiKeys[ProviderDefaults.ApiKey.openAILlm]
                ?? config.apiKeys[ProviderDefaults.ApiKey.openAI]
                ?? ""
            return OpenAILlmProcessor(apiKey: key, model: resolved(.openAILlm), promptManager: promptManager)
        case .claude:
            let key = config.apiKeys[ProviderDefaults.ApiKey.anthropic] ?? ""
            return ClaudeLlmProcessor(apiKey: key, model: resolved(.claude), promptManager: promptManager)
        case .geminiApi:
            let key = config.apiKeys[ProviderDefaults.ApiKey.googleAI] ?? ""
            return GeminiApiProcessor(apiKey: key, model: resolved(.geminiApi), promptManager: promptManager)
        case .customOpenAI:
            let key = config.apiKeys[ProviderDefaults.ApiKey.customOpenAI] ?? ""
            return CustomOpenAIProcessor(
                apiKey: key,
                model: resolved(.customOpenAI),
                baseURL: config.httpLlmConfig.customBaseUrl,
                promptManager: promptManager
            )
        }
    }
}
