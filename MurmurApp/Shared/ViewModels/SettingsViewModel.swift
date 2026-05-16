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

    // Custom OpenAI-compatible LLM endpoint
    var customBaseUrl: String = "http://localhost:11434/v1"
    var customDisplayName: String = "Ollama"

    // Custom OpenAI-compatible STT endpoint
    var customSttKey: String = ""
    var customSttBaseUrl: String = "http://localhost:8080"
    var customSttDisplayName: String = "Custom STT"
    var customSttModel: String = "whisper-1"

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

    // Prompts editor state
    var promptSet: PromptSet = PromptSet()
    var selectedPrompt: PromptName = .postProcess
    var draftPromptContent: String = ""
    var promptSaveError: String?

    // Apple STT model status
    var appleSttModelStatus: AppleSttModelStatus = .notInstalled
    var appleSttDownloadError: String?
    private let appleSttModelManager = AppleSttModelManager()

    // MARK: - Internal
    private let configManager: ConfigManager
    /// Directory used for prompt overrides. Defaults to the same parent dir
    /// that ConfigManager writes config.json into.
    private let promptsDirectory: URL

    init(
        configManager: ConfigManager,
        promptsDirectory: URL = ConfigManager.defaultDirectory
    ) {
        self.configManager = configManager
        self.promptsDirectory = promptsDirectory
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
        customSttKey = config.apiKeys["custom_stt"] ?? ""
        customSttBaseUrl = config.httpSttConfig.customBaseUrl
        customSttDisplayName = config.httpSttConfig.customDisplayName
        customSttModel = config.httpSttConfig.customModel
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
        if !customSttKey.isEmpty { keys["custom_stt"] = customSttKey }

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
            httpLlmConfig: HttpLlmConfig(customBaseUrl: customBaseUrl, customDisplayName: customDisplayName),
            httpSttConfig: HttpSttConfig(customBaseUrl: customSttBaseUrl, customDisplayName: customSttDisplayName, customModel: customSttModel)
        )

        do {
            try await configManager.setConfig(newConfig)
            NotificationCenter.default.post(name: .murmurConfigDidChange, object: nil)
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
        func resolved(_ type: LlmProcessorType) -> String {
            modelOverride ?? ProviderDefaults.defaultModel(for: type)
        }

        switch llmProcessor {
        case .appleLlm:
            return AppleLlmProcessor()
        case .gemini:
            return GeminiProcessor(model: resolved(.gemini))
        case .copilot:
            return CopilotProcessor(model: resolved(.copilot))
        case .openAILlm:
            return OpenAILlmProcessor(apiKey: openAIKey, model: resolved(.openAILlm))
        case .claude:
            return ClaudeLlmProcessor(apiKey: anthropicKey, model: resolved(.claude))
        case .geminiApi:
            return GeminiApiProcessor(apiKey: googleAiKey, model: resolved(.geminiApi))
        case .customOpenAI:
            return CustomOpenAIProcessor(
                apiKey: customOpenAIKey,
                model: resolved(.customOpenAI),
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

    // MARK: - Prompts

    /// Load any on-disk prompt overrides into `promptSet` and seed the
    /// editor draft with the current value of `selectedPrompt`.
    func loadPrompts() async {
        do {
            promptSet = try PromptStore.loadAll(configDir: promptsDirectory)
        } catch {
            promptSaveError = error.localizedDescription
        }
        draftPromptContent = promptSet.get(selectedPrompt)
    }

    /// Select a different template and refresh the editor draft.
    func selectPrompt(_ name: PromptName) {
        selectedPrompt = name
        draftPromptContent = promptSet.get(name)
        promptSaveError = nil
    }

    /// Persist the current draft as an override for `selectedPrompt`.
    func savePrompt() async {
        do {
            try PromptStore.save(selectedPrompt, content: draftPromptContent, in: promptsDirectory)
            promptSet.setOverride(selectedPrompt, content: draftPromptContent)
            promptSaveError = nil
            NotificationCenter.default.post(name: .murmurConfigDidChange, object: nil)
        } catch {
            promptSaveError = error.localizedDescription
        }
    }

    /// Remove the override and restore the compile-time default for
    /// `selectedPrompt`. Also rewinds the editor draft.
    func resetPrompt() async {
        do {
            try PromptStore.reset(selectedPrompt, in: promptsDirectory)
            promptSet.clearOverride(selectedPrompt)
            draftPromptContent = selectedPrompt.defaultTemplate
            promptSaveError = nil
            NotificationCenter.default.post(name: .murmurConfigDidChange, object: nil)
        } catch {
            promptSaveError = error.localizedDescription
        }
    }

    /// Required placeholders that are missing from the current draft. The
    /// Settings UI uses this to warn the user before saving.
    var missingPlaceholders: [String] {
        selectedPrompt.requiredPlaceholders.filter { !draftPromptContent.contains($0) }
    }

    // MARK: - Apple STT model status

    /// Refresh `appleSttModelStatus` from disk for the current locale.
    func refreshAppleSttModelStatus() async {
        let locale = resolvedAppleSttLocale()
        appleSttModelStatus = await appleSttModelManager.status(for: locale)
    }

    /// Trigger an on-disk download for the current locale. Updates
    /// `appleSttModelStatus` to `.downloading(_)` while running.
    func downloadAppleSttModel() async {
        let locale = resolvedAppleSttLocale()
        appleSttDownloadError = nil
        appleSttModelStatus = .downloading(0)
        do {
            try await appleSttModelManager.download(for: locale) { [weak self] fraction in
                Task { @MainActor in
                    self?.appleSttModelStatus = .downloading(fraction)
                }
            }
            appleSttModelStatus = .installed
        } catch {
            appleSttDownloadError = error.localizedDescription
            appleSttModelStatus = .error(error.localizedDescription)
        }
    }

    private func resolvedAppleSttLocale() -> Locale {
        appleSttLocale == "auto" ? Locale.current : Locale(identifier: appleSttLocale)
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
        case .customStt: return "API Key (optional)"
        }
    }
}
