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

    // LLM model override (empty = provider default)
    var llmModel: String = ""

    // API keys by provider name
    var elevenLabsKey: String = ""
    var openAIKey: String = ""
    var groqKey: String = ""
    var anthropicKey: String = ""
    var googleAiKey: String = ""
    var customOpenAIKey: String = ""

    // Custom OpenAI-compatible endpoint
    var customBaseUrl: String = "http://localhost:11434/v1"
    var customDisplayName: String = "Ollama"

    // Personal dictionary — legacy terms
    var dictionaryTerms: [String] = []
    var newTerm: String = ""

    // Personal dictionary — rich entries
    var dictionaryEntries: [DictionaryEntry] = []
    var dictionarySearch: String = ""
    var newEntryTerm: String = ""
    var newEntryAlias: String = ""
    var newEntryDescription: String = ""

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
        anthropicKey = config.apiKeys["anthropic"] ?? ""
        googleAiKey = config.apiKeys["google_ai"] ?? ""
        customOpenAIKey = config.apiKeys["custom_openai"] ?? ""
        llmModel = config.llmModel
        customBaseUrl = config.httpLlmConfig.customBaseUrl
        customDisplayName = config.httpLlmConfig.customDisplayName
        dictionaryTerms = config.personalDictionary.terms
        dictionaryEntries = config.personalDictionary.entries
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
        if !anthropicKey.isEmpty { keys["anthropic"] = anthropicKey }
        if !googleAiKey.isEmpty { keys["google_ai"] = googleAiKey }
        if !customOpenAIKey.isEmpty { keys["custom_openai"] = customOpenAIKey }

        let newConfig = AppConfig(
            sttProvider: sttProvider,
            apiKeys: keys,
            hotkey: hotkey,
            llmProcessor: llmProcessor,
            outputMode: outputMode,
            uiPreferences: UiPreferences(opacity: opacity, showWaveform: showWaveform, theme: theme),
            appleSttLocale: appleSttLocale,
            personalDictionary: PersonalDictionary(terms: dictionaryTerms, entries: dictionaryEntries),
            sttLanguage: sttLanguage,
            llmModel: llmModel,
            httpLlmConfig: HttpLlmConfig(customBaseUrl: customBaseUrl, customDisplayName: customDisplayName)
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
        let modelOverride = llmModel.isEmpty ? nil : llmModel

        switch llmProcessor {
        case .appleLlm:
            return AppleLlmProcessor()
        case .gemini:
            return GeminiProcessor(model: modelOverride ?? "gemini-2.5-flash")
        case .copilot:
            return CopilotProcessor()
        case .openAILlm:
            let key = openAIKey.isEmpty ? "" : openAIKey
            return OpenAILlmProcessor(apiKey: key, model: modelOverride ?? "gpt-4o-mini")
        case .claude:
            return ClaudeLlmProcessor(apiKey: anthropicKey, model: modelOverride ?? "claude-sonnet-4-20250514")
        case .geminiApi:
            return GeminiApiProcessor(apiKey: googleAiKey, model: modelOverride ?? "gemini-2.0-flash")
        case .customOpenAI:
            return CustomOpenAIProcessor(
                apiKey: customOpenAIKey,
                model: modelOverride ?? "llama3",
                baseURL: customBaseUrl
            )
        }
    }

    // MARK: - Dictionary Entry CRUD

    func addEntry() {
        let trimmed = newEntryTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let entry = DictionaryEntry(
            term: trimmed,
            alias: newEntryAlias.isEmpty ? nil : newEntryAlias.trimmingCharacters(in: .whitespaces),
            description: newEntryDescription.isEmpty ? nil : newEntryDescription.trimmingCharacters(in: .whitespaces)
        )
        dictionaryEntries.append(entry)
        newEntryTerm = ""
        newEntryAlias = ""
        newEntryDescription = ""
        Task { await saveConfig() }
    }

    func removeEntry(_ entry: DictionaryEntry) {
        dictionaryEntries.removeAll { $0.id == entry.id }
        Task { await saveConfig() }
    }

    func updateEntry(_ entry: DictionaryEntry) {
        if let index = dictionaryEntries.firstIndex(where: { $0.id == entry.id }) {
            dictionaryEntries[index] = entry
            Task { await saveConfig() }
        }
    }

    var filteredEntries: [DictionaryEntry] {
        if dictionarySearch.isEmpty {
            return dictionaryEntries
        }
        let dict = PersonalDictionary(entries: dictionaryEntries)
        return dict.search(dictionarySearch)
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
