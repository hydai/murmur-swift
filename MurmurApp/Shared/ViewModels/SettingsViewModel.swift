import SwiftUI
import MurmurKit

/// Drives the Settings UI by maintaining a local copy of AppConfig
/// and syncing changes back to ConfigManager.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Config mirror (local copy for UI binding)
    var sttProvider: SttProviderType = .appleStt
    var llmProcessor: LlmProcessorType = .appleLlm
    var outputMode: OutputMode = .clipboard
    var hotkey: String = "Ctrl+`"
    var appleSttLocale: String = "auto"
    var sttLanguage: String = "auto"
    var opacity: Float = 0.9
    var showWaveform: Bool = true
    var theme: String = "dark"

    // API keys by provider name
    var elevenLabsKey: String = ""
    var openAIKey: String = ""
    var groqKey: String = ""

    // Personal dictionary
    var dictionaryTerms: [String] = []
    var newTerm: String = ""

    // UI state
    var saveError: String?
    var isSaving: Bool = false
    var llmHealthStatus: String?

    // MARK: - Internal
    private let configManager: ConfigManager

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    // MARK: - Load

    func loadConfig() async {
        let config = await configManager.getConfig()
        sttProvider = config.sttProvider
        llmProcessor = config.llmProcessor
        outputMode = config.outputMode
        hotkey = config.hotkey
        appleSttLocale = config.appleSttLocale
        sttLanguage = config.sttLanguage
        opacity = config.uiPreferences.opacity
        showWaveform = config.uiPreferences.showWaveform
        theme = config.uiPreferences.theme
        elevenLabsKey = config.apiKeys["elevenlabs"] ?? ""
        openAIKey = config.apiKeys["openai"] ?? ""
        groqKey = config.apiKeys["groq"] ?? ""
        dictionaryTerms = config.personalDictionary.terms
    }

    // MARK: - Save

    func saveConfig() async {
        isSaving = true
        saveError = nil

        // Build config locally (Sendable struct) to avoid actor isolation issues
        var keys: [String: String] = [:]
        if !elevenLabsKey.isEmpty { keys["elevenlabs"] = elevenLabsKey }
        if !openAIKey.isEmpty { keys["openai"] = openAIKey }
        if !groqKey.isEmpty { keys["groq"] = groqKey }

        let newConfig = AppConfig(
            sttProvider: sttProvider,
            apiKeys: keys,
            hotkey: hotkey,
            llmProcessor: llmProcessor,
            outputMode: outputMode,
            uiPreferences: UiPreferences(opacity: opacity, showWaveform: showWaveform, theme: theme),
            appleSttLocale: appleSttLocale,
            personalDictionary: PersonalDictionary(terms: dictionaryTerms),
            sttLanguage: sttLanguage
        )

        do {
            try await configManager.setConfig(newConfig)
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Dictionary CRUD

    func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !dictionaryTerms.contains(trimmed) else { return }
        dictionaryTerms.append(trimmed)
        newTerm = ""
        Task { await saveConfig() }
    }

    func removeTerm(at offsets: IndexSet) {
        dictionaryTerms.remove(atOffsets: offsets)
        Task { await saveConfig() }
    }

    // MARK: - LLM Health Check

    func checkLlmHealth() async {
        llmHealthStatus = "Checking..."
        let processor = createLlmProcessor()
        let healthy = await processor.healthCheck()
        llmHealthStatus = healthy ? "Available" : "Unavailable"
    }

    private func createLlmProcessor() -> any LlmProcessor {
        switch llmProcessor {
        case .appleLlm:
            return AppleLlmProcessor()
        case .gemini:
            return GeminiProcessor()
        case .copilot:
            return CopilotProcessor()
        }
    }

    /// Which API key fields to show based on selected STT provider.
    var requiresApiKey: Bool {
        sttProvider != .appleStt
    }

    /// Display name for the current STT provider's API key field.
    var apiKeyLabel: String {
        switch sttProvider {
        case .appleStt: return ""
        case .elevenLabs: return "ElevenLabs API Key"
        case .openAI: return "OpenAI API Key"
        case .groq: return "Groq API Key"
        }
    }
}
